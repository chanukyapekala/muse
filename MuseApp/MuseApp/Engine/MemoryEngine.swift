import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class MemoryEngine {
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let clusterThreshold: Double = 0.35

    func process(prompt: String, answer: String, modelContext: ModelContext, generate: (String) async throws -> String) async {
        // Keep prompt short — 1B models struggle with long context + structured output
        let truncatedPrompt = String(prompt.prefix(300))

        let extractionPrompt = """
        List up to 3 personal facts about the user from this message. Each fact on its own line. Start each line with "- ". If no personal facts, write "none".

        User message: \(truncatedPrompt)

        Facts:
        """

        guard let raw = try? await generate(extractionPrompt) else { return }

        let facts = parseLines(raw)
        guard !facts.isEmpty else { return }

        let existingClusters = (try? modelContext.fetch(FetchDescriptor<MemoryCluster>())) ?? []

        for fact in facts {
            let clusterID = resolveCluster(for: fact, existing: existingClusters, modelContext: modelContext)
            let memory = Memory(fact: fact, clusterID: clusterID)
            modelContext.insert(memory)
        }
    }

    // Parse "- fact" lines, ignore noise
    private func parseLines(_ text: String) -> [String] {
        var results: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else { continue }
            let fact = trimmed.drop(while: { $0 == "-" || $0 == " " })
                .trimmingCharacters(in: .whitespaces)
            guard !fact.isEmpty, fact.lowercased() != "none", fact.count > 5 else { continue }
            results.append(fact)
            if results.count == 3 { break }
        }
        return results
    }

    private func resolveCluster(for fact: String, existing: [MemoryCluster], modelContext: ModelContext) -> UUID {
        guard let embedding else {
            return makeCluster(label: shortLabel(fact), embeddingVector: [], modelContext: modelContext)
        }

        let factVector = embedding.vector(for: fact) ?? []
        var bestCluster: MemoryCluster?
        var bestDistance = Double.infinity

        for cluster in existing {
            let d = cosineSimilarity(factVector, cluster.embedding)
            if d < bestDistance { bestDistance = d; bestCluster = cluster }
        }

        if let match = bestCluster, bestDistance < clusterThreshold {
            return match.id
        }

        return makeCluster(label: shortLabel(fact), embeddingVector: factVector, modelContext: modelContext)
    }

    private func makeCluster(label: String, embeddingVector: [Double], modelContext: ModelContext) -> UUID {
        let cluster = MemoryCluster(label: label, embedding: embeddingVector)
        modelContext.insert(cluster)
        return cluster.id
    }

    private func shortLabel(_ fact: String) -> String {
        fact.split(separator: " ").prefix(4).joined(separator: " ")
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1.0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 1.0 }
        return 1.0 - (dot / (magA * magB))
    }
}
