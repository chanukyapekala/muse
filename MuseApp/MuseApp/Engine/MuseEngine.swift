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

    let mlxProvider = MLXProvider()
    let memoryEngine = MemoryEngine()
    private var cancellables = Set<AnyCancellable>()

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

    func ideate(prompt: String, modelContext: ModelContext) async {
        isLoading = true
        loadingStatus = "Thinking..."
        lastPrompt = prompt
        error = nil
        currentResponse = nil

        let system = buildSystemPrompt(modelContext: modelContext)

        do {
            let result = try await mlxProvider.generate(prompt: prompt, system: system, maxTokens: 2048)
            if let err = result.error {
                error = err
            } else {
                currentResponse = MuseResponse(prompt: prompt, answer: result.content)

                // Extract memories using NLTagger only — no second model call
                memoryEngine.process(prompt: prompt, modelContext: modelContext)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func buildSystemPrompt(modelContext: ModelContext) -> String {
        var base = "You are a helpful AI assistant. Provide a thorough, well-structured response."

        let descriptor = FetchDescriptor<MemoryCluster>(
            sortBy: [SortDescriptor(\MemoryCluster.lastSeen, order: .reverse)]
        )
        let clusters = (try? modelContext.fetch(descriptor)) ?? []
        guard !clusters.isEmpty else { return base }

        let topics = clusters.prefix(12).map(\.label).joined(separator: ", ")
        base += "\n\nThis user has recently discussed: \(topics). Use this context naturally."
        return base
    }
}
