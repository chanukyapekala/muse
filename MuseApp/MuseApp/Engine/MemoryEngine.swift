import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class MemoryEngine {
    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let clusterThreshold: Double = 0.35

    // Extract facts using NLTagger only — no second Llama call, no memory spike.
    func process(prompt: String, modelContext: ModelContext) {
        let facts = extractFacts(from: prompt)
        guard !facts.isEmpty else { return }

        let existingClusters = (try? modelContext.fetch(FetchDescriptor<MemoryCluster>())) ?? []
        for fact in facts {
            let clusterID = resolveCluster(for: fact, existing: existingClusters, modelContext: modelContext)
            modelContext.insert(Memory(fact: fact, clusterID: clusterID))
        }
    }

    // Extract meaningful noun phrases from the user's message using NLTagger.
    private func extractFacts(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        var nouns: [String] = []
        var facts: [String] = []

        // Pass 1: named entities (person, place, org)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag != nil {
                nouns.append(String(text[range]))
            }
            return true
        }

        // Pass 2: significant nouns that aren't stop words
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 3 && !stopWords.contains(word) {
                    nouns.append(word)
                }
            }
            return true
        }

        guard !nouns.isEmpty else { return [] }

        // Build a concise fact from the full sentence if it's personal
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        for sentence in sentences {
            let s = sentence.trimmingCharacters(in: .whitespaces)
            guard s.count > 10 else { continue }
            let lower = s.lowercased()
            // Only extract first-person statements
            if lower.hasPrefix("i ") || lower.hasPrefix("i'm") || lower.hasPrefix("i am") || lower.hasPrefix("my ") {
                let fact = s.prefix(120).description
                facts.append(fact)
                if facts.count == 3 { break }
            }
        }

        return facts
    }

    private let stopWords: Set<String> = [
        "this", "that", "with", "from", "they", "them", "their", "have",
        "will", "would", "could", "should", "been", "being", "were", "what",
        "when", "where", "which", "there", "here", "just", "like", "also",
        "some", "more", "than", "then", "into", "your", "about"
    ]

    private func resolveCluster(for fact: String, existing: [MemoryCluster], modelContext: ModelContext) -> UUID {
        guard let sentenceEmbedding else {
            return makeCluster(label: topicLabel(fact), embeddingVector: [], modelContext: modelContext)
        }
        let vector = sentenceEmbedding.vector(for: fact) ?? []
        var best: MemoryCluster?
        var bestDist = Double.infinity
        for cluster in existing {
            let d = cosineSimilarity(vector, cluster.embedding)
            if d < bestDist { bestDist = d; best = cluster }
        }
        if let match = best, bestDist < clusterThreshold { return match.id }
        return makeCluster(label: topicLabel(fact), embeddingVector: vector, modelContext: modelContext)
    }

    private func makeCluster(label: String, embeddingVector: [Double], modelContext: ModelContext) -> UUID {
        let cluster = MemoryCluster(label: label, embedding: embeddingVector)
        modelContext.insert(cluster)
        return cluster.id
    }

    private func topicLabel(_ fact: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = fact
        var keywords: [String] = []
        tagger.enumerateTags(in: fact.startIndex..<fact.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun || tag == .verb {
                let w = String(fact[range]).lowercased()
                if w.count > 3 && !stopWords.contains(w) { keywords.append(w) }
            }
            return keywords.count < 2
        }
        return keywords.isEmpty ? String(fact.prefix(20)) : keywords.joined(separator: " ")
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
