// MuseEngine.swift — Single on-device MLX call. No fan-out, no judge.

import Combine
import Foundation

@MainActor
class MuseEngine: ObservableObject {
    @Published var isLoading = false
    @Published var loadingStatus: String = ""
    @Published var currentResponse: MuseResponse?
    @Published var error: String?
    @Published var lastPrompt: String = ""

    let mlxProvider = MLXProvider()
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
    }

    func ideate(prompt: String) async {
        isLoading = true
        loadingStatus = "Thinking..."
        lastPrompt = prompt
        error = nil
        currentResponse = nil

        let system = "You are a helpful AI assistant. Provide a thorough, well-structured response."

        do {
            let result = try await mlxProvider.generate(prompt: prompt, system: system, maxTokens: 2048)
            if let err = result.error {
                error = err
            } else {
                currentResponse = MuseResponse(prompt: prompt, answer: result.content)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
