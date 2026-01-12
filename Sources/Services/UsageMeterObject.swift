import Foundation
import Observation

@Observable
final class UsageMeterObject {
  func incrementMessage() {}

  func remainingDailyMessages(for level: SubscriptionLevel, trialActive: Bool) -> Int {
    return 100
  }
}
