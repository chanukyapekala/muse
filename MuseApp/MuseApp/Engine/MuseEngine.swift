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
                let response = MuseResponse(prompt: prompt, answer: result.content)
                currentResponse = response

                // Extract memories in background — don't block the UI
                Task {
                    await memoryEngine.process(
                        prompt: prompt,
                        answer: result.content,
                        modelContext: modelContext
                    ) { [weak self] (extractionPrompt: String) in
                        guard let self else { return "" }
                        let r = try await self.mlxProvider.generate(
                            prompt: extractionPrompt,
                            system: "You are a helpful assistant. Follow instructions exactly.",
                            maxTokens: 256
                        )
                        return r.content
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func buildSystemPrompt(modelContext: ModelContext) -> String {
        var base = "You are a helpful AI assistant. Provide a thorough, well-structured response."

        let descriptor = FetchDescriptor<Memory>(
            predicate: #Predicate<Memory> { $0.active == true },
            sortBy: [SortDescriptor(\Memory.createdAt)]
        )
        let memories = (try? modelContext.fetch(descriptor)) ?? []

        guard !memories.isEmpty else { return base }

        let facts = memories.map { "- \($0.fact)" }.joined(separator: "\n")
        base += "\n\nWhat you know about this user:\n\(facts)\n\nUse this context naturally without mentioning that you have a memory system."
        return base
    }
}
