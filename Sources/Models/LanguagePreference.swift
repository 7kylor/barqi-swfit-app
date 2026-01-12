import Foundation
import SwiftData

@Model
final class LanguagePreference {
  var preferredLanguageRaw: String
  @Relationship(inverse: \Conversation.languageSettings) var conversation: Conversation?

  init(preferredLanguage: DetectedLanguage = .english) {
    self.preferredLanguageRaw = preferredLanguage.rawValue
  }
}

extension LanguagePreference {
  var preferredLanguage: DetectedLanguage {
    get { DetectedLanguage(rawValue: preferredLanguageRaw) ?? .english }
    set { preferredLanguageRaw = newValue.rawValue }
  }
}

enum DetectedLanguage: String, Codable, CaseIterable, Sendable {
  case english = "en"
  case arabic = "ar"
  case unknown = "unk"

  var displayName: String {
    switch self {
    case .english: return "English"
    case .arabic: return "Arabic"
    case .unknown: return "Unknown"
    }
  }
}
