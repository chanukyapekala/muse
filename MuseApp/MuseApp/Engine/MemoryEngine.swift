import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class MemoryEngine {
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let clusterThreshold: Double = 0.35

    func process(prompt: String, answer: String, modelContext: ModelContext, generate: (String) async throws -> String) async {
        // Only extract from the user's message — not the assistant's response
        let truncatedPrompt = String(prompt.prefix(200))

        let extractionPrompt = """
        Read this message and list personal facts about the person who wrote it. Only include facts clearly stated by the user. Each fact on its own line starting with "- ". Maximum 3 facts. If none, write "none".

        Message: \(truncatedPrompt)

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
        // Use NLTagger to extract the most relevant noun/keyword
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = fact
        var keywords: [String] = []
        tagger.enumerateTags(in: fact.startIndex..<fact.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag, (tag == .noun || tag == .verb), range.upperBound > range.lowerBound {
                let word = String(fact[range]).lowercased()
                if word.count > 3 { keywords.append(word) }
            }
            return keywords.count < 2
        }
        return keywords.isEmpty
            ? String(fact.split(separator: " ").prefix(2).joined(separator: " "))
            : keywords.joined(separator: " ")
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
