import Foundation
import Observation

@Observable
final class SignInWithAppleService {
  static let shared = SignInWithAppleService()

  var isAuthenticated: Bool = false

  func signIn() async throws -> Bool {
    // Mock implementation
    return false
  }
}
