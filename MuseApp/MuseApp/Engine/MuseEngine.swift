// MuseEngine.swift — Orchestrator: fan-out to providers, judge, synthesize

import Combine
import Foundation

@MainActor
class MuseEngine: ObservableObject {
    @Published var isLoading = false
    @Published var loadingStatus: String = ""
    @Published var currentResponse: MuseResponse?
    @Published var error: String?
    @Published var lastPrompt: String = ""

    private var providers: [ModelProvider] = []
    private var cancellables = Set<AnyCancellable>()

    let mlxProvider = MLXProvider()

    init() {
        reloadProviders()
        // Forward MLX status to engine loading status
        mlxProvider.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if !status.isEmpty {
                    self?.loadingStatus = status
                }
            }
            .store(in: &cancellables)
    }

    func reloadProviders() {
        providers = [
            mlxProvider,
            AnthropicProvider(),
            OpenAIProvider(),
            OpenAIProvider(
                slug: "gemini",
                name: "Gemini",
                model: "google/gemini-2.0-flash-001",
                baseURL: "https://openrouter.ai/api/v1/chat/completions",
                apiKeyName: "openrouter_api_key"
            )
        ]
    }

    var availableProviders: [ModelProvider] {
        providers.filter { $0.isAvailable() }
    }

    func ideate(prompt: String, skipJudge: Bool = false) async {
        isLoading = true
        loadingStatus = "Thinking..."
        lastPrompt = prompt
        error = nil
        currentResponse = nil

        let active = availableProviders
        guard !active.isEmpty else {
            error = "No API keys configured. Add keys in Settings."
            isLoading = false
            return
        }

        // Fan-out: query all providers concurrently
        let results = await fanOut(prompt: prompt, providers: active)

        let successful = results.filter { $0.error == nil && !$0.content.isEmpty }
        guard !successful.isEmpty else {
            error = "All models failed. Check your API keys."
            isLoading = false
            currentResponse = MuseResponse(
                prompt: prompt,
                answer: "All models failed to respond.",
                rawResponses: results
            )
            return
        }

        if skipJudge || successful.count == 1 {
            let answer = successful.first?.content ?? ""
            currentResponse = MuseResponse(
                prompt: prompt,
                answer: answer,
                rawResponses: results,
                totalCostUSD: results.reduce(0) { $0 + $1.costUSD }
            )
            isLoading = false
            return
        }

        // Judge: synthesize all responses
        let judged = await judge(prompt: prompt, results: successful)
        currentResponse = judged
        isLoading = false
    }

    private func fanOut(prompt: String, providers: [ModelProvider]) async -> [ModelResult] {
        let system = "You are a helpful AI assistant. Provide a thorough, well-structured response."

        return await withTaskGroup(of: ModelResult.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await provider.generate(prompt: prompt, system: system, maxTokens: 2048)
                    } catch {
                        return ModelResult(
                            name: provider.name,
                            slug: provider.slug,
                            content: "",
                            error: error.localizedDescription
                        )
                    }
                }
            }

            var results: [ModelResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func judge(prompt: String, results: [ModelResult]) async -> MuseResponse {
        let judgeProvider = AnthropicProvider(model: "claude-sonnet-4-20250514")

        var responseSummary = ""
        for (i, r) in results.enumerated() {
            responseSummary += "### Response \(i + 1) — \(r.name)\n\(r.content)\n\n"
        }

        let judgePrompt = """
        You are the Judge. The user asked: "\(prompt)"

        Below are responses from multiple AI models. Your job:
        1. Score each on Feasibility (0-10), Novelty (0-10), Specificity (0-10)
        2. Identify **Consensus**: what most models agreed on
        3. Identify **Disagreements**: where models diverged
        4. Write a **Synthesis**: the best combined answer
        5. Assign a **Trust Score** (0.0 to 1.0) — how confident you are in the synthesis

        End your response with exactly: TRUST_SCORE: X.X

        \(responseSummary)
        """

        let system = "You are an expert judge synthesizing multiple AI responses into one authoritative answer."

        do {
            let judgeResult = try await judgeProvider.generate(
                prompt: judgePrompt,
                system: system,
                maxTokens: 4096
            )

            let trustScore = extractTrustScore(from: judgeResult.content)
            let totalCost = results.reduce(0.0) { $0 + $1.costUSD } + judgeResult.costUSD

            return MuseResponse(
                prompt: prompt,
                answer: judgeResult.content,
                trustScore: trustScore,
                rawResponses: results,
                totalCostUSD: totalCost
            )
        } catch {
            return MuseResponse(
                prompt: prompt,
                answer: results.first?.content ?? "Judge failed: \(error.localizedDescription)",
                rawResponses: results,
                totalCostUSD: results.reduce(0.0) { $0 + $1.costUSD }
            )
        }
    }

    private func extractTrustScore(from text: String) -> Double? {
        let pattern = "TRUST_SCORE:\\s*([0-9]*\\.?[0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }
}
