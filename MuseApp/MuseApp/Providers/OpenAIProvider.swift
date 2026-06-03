// OpenAIProvider.swift — Direct OpenAI API calls (also works for OpenRouter)

import Foundation

class OpenAIProvider: ModelProvider {
    let slug: String
    let name: String
    private let model: String
    private let baseURL: String
    private let apiKeyName: String

    init(slug: String = "openai", name: String = "OpenAI GPT", model: String = "gpt-4o",
         baseURL: String = "https://api.openai.com/v1/chat/completions",
         apiKeyName: String = "openai_api_key") {
        self.slug = slug
        self.name = name
        self.model = model
        self.baseURL = baseURL
        self.apiKeyName = apiKeyName
    }

    func generate(prompt: String, system: String, maxTokens: Int) async throws -> ModelResult {
        let apiKey = KeychainManager.shared.get(key: apiKeyName)
        guard let apiKey, !apiKey.isEmpty else {
            return ModelResult(name: name, slug: slug, content: "", error: "API key not configured")
        }

        let messages = [
            ChatMessage(role: "system", content: system),
            ChatMessage(role: "user", content: prompt)
        ]

        let start = CFAbsoluteTimeGetCurrent()
        let result = try await APIClient.shared.chatCompletion(
            url: baseURL,
            apiKey: apiKey,
            model: model,
            messages: messages,
            maxTokens: maxTokens
        )
        let latency = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        return ModelResult(
            name: name,
            slug: slug,
            content: result.content,
            inputTokens: result.inputTokens,
            outputTokens: result.outputTokens,
            latencyMs: latency
        )
    }

    func isAvailable() -> Bool {
        guard let key = KeychainManager.shared.get(key: apiKeyName) else { return false }
        return !key.isEmpty
    }
}
