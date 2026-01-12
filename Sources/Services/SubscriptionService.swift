import Foundation
import Observation

enum EntitlementLevel: String, Codable, Sendable {
  case free
  case pro
}

@Observable
final class SubscriptionService {
  var currentLevel: EntitlementLevel = .pro  // Default to pro for testing
  var trialActive: Bool = false
  var trialEndDate: Date?

  func priceString(for product: String) -> String {
    return "$9.99"
  }

  func isEligibleForIntroductoryOffer(for product: String) async -> Bool {
    return false
  }

  func introductoryOfferText(for product: String) async -> String? {
    return nil
  }

  func refreshEntitlements() async {}

  func purchase(_ product: String, source: String) async {}
  func restorePurchases() async {}
}
