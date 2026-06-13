// Types.swift — Single on-device model, single response.

import Foundation

struct ModelResult: Identifiable {
    let id: UUID
    let name: String
    let slug: String
    let content: String
    let error: String?
    let latencyMs: Int

    init(
        name: String,
        slug: String,
        content: String,
        error: String? = nil,
        latencyMs: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.slug = slug
        self.content = content
        self.error = error
        self.latencyMs = latencyMs
    }
}

struct MuseResponse: Identifiable {
    let id: UUID
    let prompt: String
    let answer: String
    let createdAt: Date

    init(prompt: String, answer: String) {
        self.id = UUID()
        self.prompt = prompt
        self.answer = answer
        self.createdAt = Date()
    }
}
