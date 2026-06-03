// APIClient.swift — Shared HTTP client for direct API calls to model providers

import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .noContent:
            return "No content in response"
        }
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct ChatUsage: Codable {
    let promptTokens: Int?
    let completionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

struct ChatResponse: Codable {
    let choices: [ChatChoice]
    let usage: ChatUsage?
}

class APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared

    func chatCompletion(
        url: String,
        apiKey: String,
        model: String,
        messages: [ChatMessage],
        maxTokens: Int = 2048
    ) async throws -> (content: String, inputTokens: Int, outputTokens: Int) {
        guard let requestURL = URL(string: url) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body = ChatRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: 0.7
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, errorBody)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw APIError.noContent
        }

        return (
            content: content,
            inputTokens: chatResponse.usage?.promptTokens ?? 0,
            outputTokens: chatResponse.usage?.completionTokens ?? 0
        )
    }
}
