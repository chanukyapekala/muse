// AnthropicProvider.swift — Claude API (Messages API format, not OpenAI-compatible)

import Foundation

class AnthropicProvider: ModelProvider {
    let slug: String = "claude"
    let name: String = "Claude"
    private let model: String
    private let apiKeyName = "anthropic_api_key"

    init(model: String = "claude-sonnet-4-20250514") {
        self.model = model
    }

    func generate(prompt: String, system: String, maxTokens: Int) async throws -> ModelResult {
        let apiKey = KeychainManager.shared.get(key: apiKeyName)
        guard let apiKey, !apiKey.isEmpty else {
            return ModelResult(name: name, slug: slug, content: "", error: "API key not configured")
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return ModelResult(name: name, slug: slug, content: "", error: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let start = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        guard let httpResponse = response as? HTTPURLResponse else {
            return ModelResult(name: name, slug: slug, content: "", error: "Invalid response")
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            return ModelResult(name: name, slug: slug, content: "", error: "HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let content = decoded.content.first?.text ?? ""

        return ModelResult(
            name: name,
            slug: slug,
            content: content,
            inputTokens: decoded.usage.inputTokens,
            outputTokens: decoded.usage.outputTokens,
            latencyMs: latency
        )
    }

    func isAvailable() -> Bool {
        guard let key = KeychainManager.shared.get(key: apiKeyName) else { return false }
        return !key.isEmpty
    }
}

// MARK: - Anthropic API types

private struct AnthropicResponse: Codable {
    let content: [ContentBlock]
    let usage: AnthropicUsage
}

private struct ContentBlock: Codable {
    let type: String
    let text: String
}

private struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
