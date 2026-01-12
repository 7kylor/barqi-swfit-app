import Foundation
import Observation

@Observable
final class UsageMeterObject {
  func incrementMessage() {}

  func remainingDailyMessages(for level: EntitlementLevel, trialActive: Bool) -> Int {
    return 100
  }

  func remainingMonthlyMessages(for level: EntitlementLevel, trialActive: Bool) -> Int {
    return 3000
  }
}
