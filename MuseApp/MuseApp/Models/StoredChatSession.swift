import Foundation
import SwiftData

@Model
final class StoredChatSession {
    var id: UUID
    var prompt: String
    var answer: String
    var createdAt: Date
    var category: String?
    var embedding: [Double]
    var threadID: UUID?

    init(prompt: String, answer: String, category: String? = nil, embedding: [Double] = [], threadID: UUID? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.answer = answer
        self.createdAt = Date()
        self.category = category
        self.embedding = embedding
        self.threadID = threadID
    }
}
