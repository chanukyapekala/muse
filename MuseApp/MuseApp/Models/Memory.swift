import Foundation
import SwiftData

@Model
final class Memory {
    var id: UUID
    var fact: String
    var clusterID: UUID
    var createdAt: Date
    var active: Bool

    init(fact: String, clusterID: UUID) {
        self.id = UUID()
        self.fact = fact
        self.clusterID = clusterID
        self.createdAt = Date()
        self.active = true
    }
}

// Codable mirror for JSON export
struct MemoryExport: Codable {
    let exportedAt: Date
    let memories: [MemoryRecord]

    struct MemoryRecord: Codable {
        let id: UUID
        let fact: String
        let topic: String
        let createdAt: Date
        let active: Bool
    }
}
