import Foundation

public enum GatedFeature: String, CaseIterable, Sendable {
  case councilSession = "council_session"
  case voiceInput = "voice_input"
  case documentChat = "document_chat"
  case advancedModels = "advanced_models"
  case privateSecure = "private_secure"
  case unlimitedChat = "unlimited_chat"
  case fastPerformance = "fast_performance"

  public var rawValue: String {
    switch self {
    case .councilSession: return "council_session"
    case .voiceInput: return "voice_input"
    case .documentChat: return "document_chat"
    case .advancedModels: return "advanced_models"
    case .privateSecure: return "private_secure"
    case .unlimitedChat: return "unlimited_chat"
    case .fastPerformance: return "fast_performance"
    }
  }
}
