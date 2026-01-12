import Foundation
import SwiftData

public enum ModelProvider: String, Codable, Sendable {
  case google = "google"
  case openai = "openai"
  case anthropic = "anthropic"
  case deepseek = "deepseek"
  case apple = "apple"  // For Apple Intelligence if ever used, but mostly cloud
}

@Model
final class AIModel {
  @Attribute(.unique) var id: UUID
  var name: String
  var providerRaw: String
  var supportsReasoning: Bool
  var qualityScore: Int = 0
  var speedScore: Int = 0

  init(
    id: UUID = UUID(),
    name: String,
    provider: String,
    supportsReasoning: Bool = false,
    qualityScore: Int = 0,
    speedScore: Int = 0
  ) {
    self.id = id
    self.name = name
    self.providerRaw = provider
    self.supportsReasoning = supportsReasoning
    self.qualityScore = qualityScore
    self.speedScore = speedScore
  }

  var provider: ModelProvider {
    get { ModelProvider(rawValue: providerRaw) ?? .openai }
    set { providerRaw = newValue.rawValue }
  }
}
