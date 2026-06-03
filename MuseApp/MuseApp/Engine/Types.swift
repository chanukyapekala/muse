// Types.swift — Shared contract matching the Python engine types

import Foundation

struct ModelResult: Identifiable, Codable {
    let id: UUID
    let name: String
    let slug: String
    let content: String
    let error: String?
    let inputTokens: Int
    let outputTokens: Int
    let costUSD: Double
    let providerType: String  // "cloud" or "local"
    let latencyMs: Int

    init(
        name: String,
        slug: String,
        content: String,
        error: String? = nil,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        costUSD: Double = 0.0,
        providerType: String = "cloud",
        latencyMs: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.slug = slug
        self.content = content
        self.error = error
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.providerType = providerType
        self.latencyMs = latencyMs
    }
}

struct MuseResponse: Identifiable {
    let id: UUID
    let prompt: String
    let answer: String
    let trustScore: Double?
    let rawResponses: [ModelResult]
    let totalCostUSD: Double
    let createdAt: Date

    init(
        prompt: String,
        answer: String,
        trustScore: Double? = nil,
        rawResponses: [ModelResult] = [],
        totalCostUSD: Double = 0.0
    ) {
        self.id = UUID()
        self.prompt = prompt
        self.answer = answer
        self.trustScore = trustScore
        self.rawResponses = rawResponses
        self.totalCostUSD = totalCostUSD
        self.createdAt = Date()
    }
}
