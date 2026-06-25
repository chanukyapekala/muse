import Foundation
import NaturalLanguage
import SwiftData

@MainActor
class MemoryEngine {
    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)

    /// Records a topic for the just-completed prompt.
    /// Creates or updates the matching cluster, and connects it to the previously-used cluster.
    func recordTopic(_ rawTopic: String, modelContext: ModelContext) {
        let topic = normalize(rawTopic)
        guard !topic.isEmpty else {
            print("[Aura] recordTopic: empty topic after normalize, skipping")
            return
        }
        print("[Aura] recordTopic input='\(rawTopic)' normalized='\(topic)'")

        let clusters = (try? modelContext.fetch(FetchDescriptor<MemoryCluster>())) ?? []
        let vector = sentenceEmbedding?.vector(for: topic) ?? []
        let cluster: MemoryCluster
        if let exact = clusters.first(where: { $0.label.lowercased() == topic.lowercased() }) {
            print("[Aura] matched existing cluster '\(exact.label)'")
            cluster = exact
        } else {
            print("[Aura] creating new cluster '\(topic)' (existing: \(clusters.map(\.label)))")
            cluster = MemoryCluster(label: topic, embedding: vector)
            modelContext.insert(cluster)
        }
        cluster.count += 1
        let previousLastSeen = clusters
            .filter { $0.id != cluster.id }
            .max(by: { $0.lastSeen < $1.lastSeen })
        cluster.lastSeen = Date()

        if let prev = previousLastSeen, prev.id != cluster.id {
            print("[Aura] edge: '\(prev.label)' → '\(cluster.label)'")
            recordEdge(from: prev.id, to: cluster.id, modelContext: modelContext)
        }

        try? modelContext.save()
    }

    func embed(_ text: String) -> [Double]? {
        sentenceEmbedding?.vector(for: text)
    }

    static func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1.0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 1.0 }
        return 1.0 - (dot / (magA * magB))
    }

    // MARK: - Private helpers

    private func normalize(_ raw: String) -> String {
        let stripped = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:\"'"))
        return String(stripped.prefix(60))
    }

    private func recordEdge(from: UUID, to: UUID, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ClusterEdge>()
        let edges = (try? modelContext.fetch(descriptor)) ?? []
        let lo: UUID = from.uuidString < to.uuidString ? from : to
        let hi: UUID = from.uuidString < to.uuidString ? to : from
        var match: ClusterEdge?
        for edge in edges {
            let a = edge.fromID
            let b = edge.toID
            if (a == lo && b == hi) || (a == hi && b == lo) {
                match = edge
                break
            }
        }
        if let match {
            match.weight += 1
            match.lastSeen = Date()
        } else {
            modelContext.insert(ClusterEdge(fromID: lo, toID: hi))
        }
    }
}
