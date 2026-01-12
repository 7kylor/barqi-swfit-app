import Foundation
import SwiftData

@Model
final class ChatMessage {
  enum Role: String, Codable, CaseIterable, Sendable {
    case user
    case assistant
    case system
  }

  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var roleRaw: String
  var text: String
  var reasoning: String?
  var languageRaw: String?
  var tokensPerSecond: Double?

  @Relationship(inverse: \Conversation.messages) var conversation: Conversation?

  init(
    id: UUID = UUID(), createdAt: Date = .now, role: Role, text: String,
    conversation: Conversation? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.roleRaw = role.rawValue
    self.text = text
    self.conversation = conversation
  }

  var role: Role {
    get { Role(rawValue: roleRaw) ?? .user }
    set { roleRaw = newValue.rawValue }
  }

  var language: DetectedLanguage? {
    get {
      guard let raw = languageRaw else { return nil }
      return DetectedLanguage(rawValue: raw)
    }
    set { languageRaw = newValue?.rawValue }
  }
}
