import Foundation
import SwiftData

@Model
final class Conversation {
  @Attribute(.unique) var id: UUID
  var title: String
  var createdAt: Date
  @Relationship var messages: [ChatMessage]
  @Relationship var languageSettings: LanguagePreference?
  // Reasoning mode: auto (default), on, off
  var reasoningModeRaw: Int

  init(id: UUID = UUID(), title: String, createdAt: Date = .now, messages: [ChatMessage] = []) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.messages = messages
    self.reasoningModeRaw = ReasoningMode.auto.rawValue
  }
}

// MARK: - Reasoning Mode
enum ReasoningMode: Int, Codable, CaseIterable, Sendable {
  case auto = 0
  case on = 1
  case off = 2
}

extension Conversation {
  var reasoningMode: ReasoningMode {
    get { ReasoningMode(rawValue: reasoningModeRaw) ?? .auto }
    set { reasoningModeRaw = newValue.rawValue }
  }
}
