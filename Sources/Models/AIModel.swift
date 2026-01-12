import Foundation
import SwiftData

public enum ModelStatus: String, Codable, Sendable {
  case notDownloaded
  case downloading
  case downloaded
  case loaded
  case interrupted
  case failed
}

public enum ModelProvider: String, Codable, Sendable {
  case appleFoundation = "apple"
  case google = "google"
  case openai = "openai"
  case anthropic = "anthropic"
}

@Model
final class AIModel {
  @Attribute(.unique) var id: String
  var name: String
  var providerRaw: String
  var supportsReasoning: Bool

  // Missing properties from Mawj port
  var requiredRAMGB: Int?
  var canDownload: Bool = true
  var hasEnoughStorage: Bool = true
  var statusRaw: String = ModelStatus.notDownloaded.rawValue
  var progress: Double = 0.0
  var qualityScore: Int = 0
  var speedScore: Int = 0
  var displaySize: String = "0 GB"
  var sizeBytes: Int64 = 0
  var downloadURL: String?

  init(
    id: String = UUID().uuidString,
    name: String,
    provider: String = "apple",
    supportsReasoning: Bool = false,
    sizeBytes: Int64 = 0,
    downloadURL: String? = nil,
    status: ModelStatus = .notDownloaded,
    qualityScore: Int = 0,
    speedScore: Int = 0
  ) {
    self.id = id
    self.name = name
    self.providerRaw = provider
    self.supportsReasoning = supportsReasoning
    self.sizeBytes = sizeBytes
    self.downloadURL = downloadURL
    self.statusRaw = status.rawValue
    self.qualityScore = qualityScore
    self.speedScore = speedScore
  }
}

extension AIModel {
  var status: ModelStatus {
    get { ModelStatus(rawValue: statusRaw) ?? .notDownloaded }
    set { statusRaw = newValue.rawValue }
  }

  var provider: ModelProvider {
    get { ModelProvider(rawValue: providerRaw) ?? .appleFoundation }
    set { providerRaw = newValue.rawValue }
  }

  var friendlyName: String {
    name
  }
}
