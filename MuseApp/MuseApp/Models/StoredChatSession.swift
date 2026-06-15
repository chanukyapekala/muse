import Foundation
import SwiftData

@Model
final class StoredChatSession {
    var id: UUID
    var prompt: String
    var answer: String
    var createdAt: Date

    init(prompt: String, answer: String) {
        self.id = UUID()
        self.prompt = prompt
        self.answer = answer
        self.createdAt = Date()
    }
}
