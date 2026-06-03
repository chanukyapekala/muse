// ProviderProtocol.swift — Every model provider implements this

import Foundation

protocol ModelProvider {
    var slug: String { get }
    var name: String { get }

    func generate(prompt: String, system: String, maxTokens: Int) async throws -> ModelResult
    func isAvailable() -> Bool
}
