import Foundation
import StoreKit

@MainActor
final class AppReviewManager {
  static let shared = AppReviewManager()

  private let userDefaults = UserDefaults.standard
  private let reviewRequestKey = "com.taher.Mawj.reviewRequestCount"
  private let lastReviewRequestKey = "com.taher.Mawj.lastReviewRequestDate"
  private let significantEventKey = "com.taher.Mawj.significantEventCount"

  private init() {}

  func recordSignificantEvent() {
    let count = userDefaults.integer(forKey: significantEventKey)
    userDefaults.set(count + 1, forKey: significantEventKey)

    // Request review after 5 significant events
    if count >= 4 {
      requestReviewIfAppropriate()
    }
  }

  func requestReviewIfAppropriate() {
    // Don't request more than 3 times per year
    let requestCount = userDefaults.integer(forKey: reviewRequestKey)
    if requestCount >= 3 {
      return
    }

    // Check if we've requested in the last 90 days
    if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestKey) as? Date {
      let daysSinceLastRequest =
        Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
      if daysSinceLastRequest < 90 {
        return
      }
    }

    // Request review
    #if os(iOS)
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        AppStore.requestReview(in: windowScene)

        // Update tracking
        userDefaults.set(requestCount + 1, forKey: reviewRequestKey)
        userDefaults.set(Date(), forKey: lastReviewRequestKey)
      }
    #endif
  }

  func resetReviewTracking() {
    userDefaults.removeObject(forKey: reviewRequestKey)
    userDefaults.removeObject(forKey: lastReviewRequestKey)
    userDefaults.removeObject(forKey: significantEventKey)
  }
}

#if os(iOS)
  import UIKit
#endif
