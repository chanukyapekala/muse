import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class MemoryEngine {
    static let categories: [(label: String, description: String)] = [
        ("AI", "artificial intelligence machine learning models LLM neural networks"),
        ("Code", "programming software development coding swift python javascript debugging"),
        ("Data", "data engineering analytics database SQL pipelines statistics"),
        ("Personal", "family friends relationships home daily life feelings emotions"),
        ("Health", "fitness exercise diet sleep mental health wellness medical"),
        ("Creative", "art design writing music photography ideas storytelling"),
        ("Work", "job career meetings projects deadlines team productivity business"),
    ]

    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    private lazy var categoryVectors: [(label: String, vector: [Double])] = {
        guard let emb = sentenceEmbedding else { return [] }
        return Self.categories.compactMap { c in
            guard let v = emb.vector(for: c.description) else { return nil }
            return (c.label, v)
        }
    }()

    func process(prompt: String, modelContext: ModelContext) {
        guard let emb = sentenceEmbedding,
              let vector = emb.vector(for: prompt),
              let category = classify(vector) else { return }

        let existing = (try? modelContext.fetch(FetchDescriptor<MemoryCluster>())) ?? []
        if let match = existing.first(where: { $0.label == category }) {
            match.count += 1
            match.lastSeen = Date()
        } else {
            modelContext.insert(MemoryCluster(label: category, embedding: vector))
        }
        try? modelContext.save()
    }

    private func classify(_ vector: [Double]) -> String? {
        guard !categoryVectors.isEmpty else { return nil }
        var best: (label: String, dist: Double)?
        for c in categoryVectors {
            let d = cosineDistance(vector, c.vector)
            if best == nil || d < best!.dist { best = (c.label, d) }
        }
        return best?.label
    }

    private func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1.0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 1.0 }
        return 1.0 - (dot / (magA * magB))
    }
}
