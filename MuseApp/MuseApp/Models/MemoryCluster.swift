import Foundation
import SwiftData

@Model
final class MemoryCluster {
    var id: UUID
    var label: String
    var embedding: [Double]
    var createdAt: Date

    init(label: String, embedding: [Double]) {
        self.id = UUID()
        self.label = label
        self.embedding = embedding
        self.createdAt = Date()
    }
}
