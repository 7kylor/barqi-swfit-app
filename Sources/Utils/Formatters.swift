import Foundation

/// Centralized cached date/time formatters for performance
enum AppFormatters {
  static let mediumDateShortTime: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  static let shortTimeOnly: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
  }()

  /// Returns a Gregorian date string using Western digits.
  /// Arabic locale uses DD/MM/YYYY, all others use MM/DD/YYYY.
  static func westernDateString(_ date: Date, locale: Locale = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year, let month = components.month, let day = components.day else {
      return ""
    }
    let languageId = Locale.preferredLanguages.first?.lowercased() ?? locale.identifier.lowercased()
    let isArabic = languageId.hasPrefix("ar")
    if isArabic {
      return String(format: "%02d/%02d/%04d", day, month, year)
    } else {
      return String(format: "%02d/%02d/%04d", month, day, year)
    }
  }
}
