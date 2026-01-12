import Foundation
@preconcurrency import NaturalLanguage

struct LanguageDetector {
  @MainActor private static let recognizer = NLLanguageRecognizer()
  private static let arabicCharacterSet = CharacterSet(charactersIn: "\u{0600}"..."\u{06FF}")
    .union(CharacterSet(charactersIn: "\u{0750}"..."\u{077F}"))
    .union(CharacterSet(charactersIn: "\u{08A0}"..."\u{08FF}"))
    .union(CharacterSet(charactersIn: "\u{FB50}"..."\u{FDFF}"))
    .union(CharacterSet(charactersIn: "\u{FE70}"..."\u{FEFF}"))

  /// Format text for Arabic display (punctuation only, Western digits per user preference)
  static func shapeArabicNumeralsIfNeeded(text: String, language: DetectedLanguage?) -> String {
    guard language == .arabic else { return text }
    // Only apply punctuation localization, keep Western digits (0-9)
    return localizePunctuationIfNeeded(text, language: .arabic)
  }

  /// Localize punctuation for Arabic and ensure better bidi behavior in mixed strings
  static func localizePunctuationIfNeeded(_ text: String, language: DetectedLanguage?) -> String {
    guard language == .arabic else { return text }
    var s = text
    s = s.replacingOccurrences(of: "\"", with: "\u{201D}")  // closing double quote
    s = s.replacingOccurrences(of: "'", with: "\u{2019}")  // apostrophe
    // Add RTL mark at start if string begins with Latin to help bidi
    if let first = s.unicodeScalars.first, CharacterSet.alphanumerics.contains(first) {
      s = "\u{200F}" + s
    }
    return s
  }

  @MainActor static func detect(text: String) -> DetectedLanguage {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return .unknown
    }

    // Quick check for Arabic characters
    if containsArabicCharacters(trimmed) {
      // Verify with NLLanguageRecognizer for accuracy
      recognizer.reset()
      recognizer.processString(trimmed)

      if let language = recognizer.dominantLanguage {
        switch language {
        case .arabic:
          return .arabic
        case .english:
          // If it contains Arabic chars but detected as English, it's likely mixed
          // Prioritize Arabic for better user experience
          return .arabic
        default:
          // For any other detection with Arabic chars, assume Arabic
          return .arabic
        }
      }
      return .arabic
    }

    // Use NLLanguageRecognizer for non-Arabic text
    recognizer.reset()
    recognizer.languageConstraints = [.arabic, .english]
    recognizer.processString(trimmed)

    guard let language = recognizer.dominantLanguage else {
      return .english  // Default to English if uncertain
    }

    switch language {
    case .arabic:
      return .arabic
    case .english:
      return .english
    default:
      return .english  // Default to English for other languages
    }
  }

  @MainActor static func detectWithConfidence(text: String) -> (
    language: DetectedLanguage, confidence: Double
  ) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return (.unknown, 0.0)
    }

    recognizer.reset()
    recognizer.languageConstraints = [.arabic, .english]
    recognizer.processString(trimmed)

    let hypotheses = recognizer.languageHypotheses(withMaximum: 2)

    if let (language, confidence) = hypotheses.first {
      switch language {
      case .arabic:
        return (.arabic, confidence)
      case .english:
        return (.english, confidence)
      default:
        return (.english, 0.5)
      }
    }

    return (.english, 0.5)
  }

  private static func containsArabicCharacters(_ text: String) -> Bool {
    return text.rangeOfCharacter(from: arabicCharacterSet) != nil
  }

  static func isRTL(language: DetectedLanguage) -> Bool {
    return language == .arabic
  }
}
