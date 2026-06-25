import Foundation
import SwiftData

@Model
final class ClusterEdge {
    var id: UUID
    var fromID: UUID
    var toID: UUID
    var weight: Int
    var lastSeen: Date

    init(fromID: UUID, toID: UUID, weight: Int = 1) {
        self.id = UUID()
        self.fromID = fromID
        self.toID = toID
        self.weight = weight
        self.lastSeen = Date()
    }
}
