// MuseEngine.swift — Single on-device MLX call. No fan-out, no judge.

import Combine
import Foundation
import SwiftData

@MainActor
class MuseEngine: ObservableObject {
    @Published var isLoading = false
    @Published var loadingStatus: String = ""
    @Published var currentResponse: MuseResponse?
    @Published var error: String?
    @Published var lastPrompt: String = ""
    @Published var isModelReady: Bool = false
    @Published var selectedTab: Int = 0
    @Published var pendingPrompt: String?
    @Published var currentThreadID: UUID?

    let mlxProvider = MLXProvider()
    let memoryEngine = MemoryEngine()
    private var cancellables = Set<AnyCancellable>()

    // Recent turns to inject for in-conversation continuity (WhatsApp-style).
    private let recentTurnsToInject = 6
    private let deepTopK = 5
    private let deepThreshold: Double = 0.7

    init() {
        mlxProvider.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if !status.isEmpty {
                    self?.loadingStatus = status
                }
            }
            .store(in: &cancellables)

        mlxProvider.$isReady
            .receive(on: RunLoop.main)
            .assign(to: \.isModelReady, on: self)
            .store(in: &cancellables)
    }

    func preloadModelIfNeeded() {
        guard !mlxProvider.isReady else { return }
        Task { [mlxProvider] in
            try? await mlxProvider.loadModel()
        }
    }

    func ideate(prompt: String, modelContext: ModelContext, deepContext: Bool = false) async {
        isLoading = true
        loadingStatus = deepContext ? "Pulling more context..." : "Thinking..."
        lastPrompt = prompt
        error = nil
        currentResponse = nil

        let thread = ensureCurrentThread(modelContext: modelContext)
        let vector = memoryEngine.embed(prompt) ?? []
        let recentTurns = fetchRecentTurns(threadID: thread.id, modelContext: modelContext)
        let retrieved = deepContext ? retrieveSimilar(to: vector, modelContext: modelContext) : []
        let system = buildSystemPrompt(modelContext: modelContext, recentTurns: recentTurns, retrieved: retrieved, deep: deepContext)

        do {
            let result = try await mlxProvider.generate(prompt: prompt, system: system, maxTokens: 2048)
            if let err = result.error {
                error = err
            } else {
                let (cleanAnswer, topic) = parseTopic(from: result.content)
                print("[Aura] LLM topic parsed: \(topic ?? "nil") — answer tail: '...\(result.content.suffix(80))'")
                currentResponse = MuseResponse(prompt: prompt, answer: cleanAnswer)
                modelContext.insert(StoredChatSession(
                    prompt: prompt,
                    answer: cleanAnswer,
                    category: topic,
                    embedding: vector,
                    threadID: thread.id
                ))
                if thread.title == "New chat" {
                    thread.title = String(prompt.prefix(40))
                }
                thread.updatedAt = Date()
                if let topic {
                    memoryEngine.recordTopic(topic, modelContext: modelContext)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Returns the active thread, creating a new one if none is set or the set ID is stale.
    @discardableResult
    func ensureCurrentThread(modelContext: ModelContext) -> ChatThread {
        if let id = currentThreadID,
           let existing = try? modelContext.fetch(FetchDescriptor<ChatThread>(predicate: #Predicate { $0.id == id })).first {
            return existing
        }
        let thread = ChatThread()
        modelContext.insert(thread)
        currentThreadID = thread.id
        return thread
    }

    func startNewThread(modelContext: ModelContext) {
        let thread = ChatThread()
        modelContext.insert(thread)
        currentThreadID = thread.id
    }

    func switchToThread(_ id: UUID) {
        currentThreadID = id
    }

    /// Pulls a "TOPIC: <words>" trailing line out of the model output and returns (cleanedAnswer, topic?).
    private func parseTopic(from raw: String) -> (String, String?) {
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for i in stride(from: lines.count - 1, through: max(lines.count - 4, 0), by: -1) {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix("TOPIC:") else { continue }
            let raw = line.dropFirst("TOPIC:".count).trimmingCharacters(in: .whitespaces)
            let cleaned = raw
                .trimmingCharacters(in: CharacterSet(charactersIn: "[](){}<>\"'."))
                .components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? raw
            let body = lines[0..<i].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (body, cleaned.isEmpty ? nil : cleaned)
        }
        return (raw.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    private func fetchRecentTurns(threadID: UUID, modelContext: ModelContext) -> [StoredChatSession] {
        var descriptor = FetchDescriptor<StoredChatSession>(
            predicate: #Predicate { $0.threadID == threadID },
            sortBy: [SortDescriptor(\StoredChatSession.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = recentTurnsToInject
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        return recent.reversed()
    }

    private func retrieveSimilar(to vector: [Double], modelContext: ModelContext) -> [StoredChatSession] {
        guard !vector.isEmpty else { return [] }
        let descriptor = FetchDescriptor<StoredChatSession>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let scored = all.compactMap { session -> (StoredChatSession, Double)? in
            guard session.embedding.count == vector.count, !session.embedding.isEmpty else { return nil }
            let d = MemoryEngine.cosineDistance(vector, session.embedding)
            return d < deepThreshold ? (session, d) : nil
        }
        return scored.sorted { $0.1 < $1.1 }.prefix(deepTopK).map { $0.0 }
    }

    private func buildSystemPrompt(modelContext: ModelContext, recentTurns: [StoredChatSession], retrieved: [StoredChatSession], deep: Bool) -> String {
        var base = deep
            ? "You are a helpful AI assistant. Provide an in-depth, well-structured response, weaving in the user's relevant past conversations where they help."
            : "You are a helpful AI assistant. Provide a concise, well-structured response."

        base += "\n\nAt the very end of your response, on a new line by itself, output exactly:\nTOPIC: <2-4 word topic of the user's question>\nKeep the topic short, concrete, and consistent across similar questions."

        let descriptor = FetchDescriptor<MemoryCluster>(
            sortBy: [SortDescriptor(\MemoryCluster.lastSeen, order: .reverse)]
        )
        let clusters = (try? modelContext.fetch(descriptor)) ?? []
        if !clusters.isEmpty {
            let topics = clusters.prefix(8).map(\.label).joined(separator: ", ")
            base += "\n\nKnown topics this user has explored: \(topics). Reuse one of these labels in TOPIC if it fits."
        }

        if !recentTurns.isEmpty {
            let turns = recentTurns.map { s in
                "User: \(s.prompt)\nAssistant: \(s.answer.prefix(400))"
            }.joined(separator: "\n\n")
            base += "\n\nConversation so far:\n\(turns)"
        }

        if deep, !retrieved.isEmpty {
            let snippets = retrieved.map { s in
                let q = s.prompt.prefix(160)
                let a = s.answer.prefix(280)
                return "- Q: \(q)\n  A: \(a)"
            }.joined(separator: "\n")
            base += "\n\nOlder relevant conversations:\n\(snippets)"
        }

        return base
    }
}
