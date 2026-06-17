import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class MemoryEngine {
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let clusterThreshold: Double = 0.35

    // Extract facts from a conversation via Llama, then cluster and store them.
    func process(prompt: String, answer: String, modelContext: ModelContext, generate: (String) async throws -> String) async {
        let extractionPrompt = """
        Extract personal facts, preferences, or context about the user from this conversation.
        Return ONLY a JSON array of short factual strings. Maximum 3 items.
        If nothing notable, return [].
        Do not include any explanation or markdown.

        User: \(prompt)
        Assistant: \(answer)
        """

        guard let raw = try? await generate(extractionPrompt),
              let data = extractJSON(from: raw),
              let facts = try? JSONDecoder().decode([String].self, from: data),
              !facts.isEmpty else { return }

        let existingClusters = (try? modelContext.fetch(FetchDescriptor<MemoryCluster>())) ?? []

        for fact in facts {
            guard !fact.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let clusterID = resolveCluster(for: fact, existing: existingClusters, modelContext: modelContext)
            let memory = Memory(fact: fact, clusterID: clusterID)
            modelContext.insert(memory)
        }
    }

    // Returns the ID of the best matching cluster, creating one if needed.
    private func resolveCluster(for fact: String, existing: [MemoryCluster], modelContext: ModelContext) -> UUID {
        guard let embedding else {
            return makeCluster(label: String(fact.prefix(30)), embeddingVector: [], modelContext: modelContext)
        }

        let factVector = embedding.vector(for: fact) ?? []

        var bestCluster: MemoryCluster?
        var bestDistance = Double.infinity

        for cluster in existing {
            let distance = cosineSimilarity(factVector, cluster.embedding)
            if distance < bestDistance {
                bestDistance = distance
                bestCluster = cluster
            }
        }

        if let match = bestCluster, bestDistance < clusterThreshold {
            return match.id
        }

        // Generate a short label from the fact (first 4 words)
        let label = fact.split(separator: " ").prefix(4).joined(separator: " ")
        return makeCluster(label: label, embeddingVector: factVector, modelContext: modelContext)
    }

    private func makeCluster(label: String, embeddingVector: [Double], modelContext: ModelContext) -> UUID {
        let cluster = MemoryCluster(label: label, embedding: embeddingVector)
        modelContext.insert(cluster)
        return cluster.id
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1.0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 1.0 }
        return 1.0 - (dot / (magA * magB))
    }

    // Pull a JSON array out of Llama's response even if it adds extra text.
    private func extractJSON(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else { return nil }
        let json = String(text[start...end])
        return json.data(using: .utf8)
    }
}
