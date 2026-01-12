import Foundation

enum AnalyticsEvent: String, Codable, Sendable {
  case activation
  case paywallShown
  case paywallDismissed
  case paywallPurchasePlus
  case paywallPurchasePro
  case paywallStartTrial
  case paywallVerifyEdu
  case purchaseInitiated
  case purchaseCompleted
  case purchaseCancelled
  case purchasePending
  case purchaseFailed
  case purchasesRestored
  case restoreFailed
  case trialStarted
  case trialConverted
  case subscriptionRenewed
  case subscriptionCancelled
  case subscriptionExpired
  case subscriptionManagementOpened
  case enteredGracePeriod
  case billingRetryStarted
  case quotaHit
  case sessionChat
  // Voice input events
  case voiceRecordingStarted
  case voiceRecordingCancelled
  case voiceTranscriptionComplete
  case voiceTranscriptionFailed
  // Text-to-speech events
  case ttsStarted
  case ttsStopped
}

struct AnalyticsRecord: Codable, Sendable {
  let event: AnalyticsEvent
  let timestamp: Date
  let properties: [String: String]
}

enum Analytics {
  private static let storageKey = "com.taher.Mawj.analytics.events"
  private static let encoder = JSONEncoder()
  private static let decoder = JSONDecoder()
  private static let maxStoredEvents = 500

  static func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
    let record = AnalyticsRecord(event: event, timestamp: Date(), properties: properties)
    #if DEBUG
      print("[Analytics] \(record.event.rawValue) props=\(properties)")
    #endif
    persist(record: record)
  }

  static func records() -> [AnalyticsRecord] {
    guard
      let data = UserDefaults.standard.data(forKey: storageKey),
      let decoded = try? decoder.decode([AnalyticsRecord].self, from: data)
    else { return [] }
    return decoded
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: storageKey)
  }

  private static func persist(record: AnalyticsRecord) {
    var existing = records()
    existing.append(record)
    if existing.count > maxStoredEvents {
      existing = Array(existing.suffix(maxStoredEvents))
    }
    if let data = try? encoder.encode(existing) {
      UserDefaults.standard.set(data, forKey: storageKey)
    }
  }
}
