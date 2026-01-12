import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class LocalizationManager {
  static let shared = LocalizationManager()

  var currentLanguage: DetectedLanguage = .english
  var languageVersion: Int = 0

  init() {}

  func setLanguage(_ language: DetectedLanguage) {
    self.currentLanguage = language
    self.languageVersion += 1
  }

  var isRTL: Bool {
    currentLanguage == .arabic
  }

  var layoutDirection: LayoutDirection {
    isRTL ? .rightToLeft : .leftToRight
  }

  var locale: Locale {
    currentLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
  }
}

// Global helpers
func L(_ key: String, comment: String = "") -> String {
  // Simple fallback for now
  return NSLocalizedString(key, bundle: Bundle.main, comment: comment)
}

func L(_ key: String, _ arg: Int, comment: String = "") -> String {
  let format = NSLocalizedString(key, bundle: Bundle.main, comment: comment)
  return String(format: format, arg)
}

func L(_ key: String, _ arg: String, comment: String = "") -> String {
  let format = NSLocalizedString(key, bundle: Bundle.main, comment: comment)
  return String(format: format, arg)
}
