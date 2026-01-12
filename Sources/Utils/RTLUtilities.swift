import SwiftUI

/// Utilities for RTL-aware layout and alignment
enum RTLUtilities {
  /// Determines if the current language preference is RTL (Right-to-Left)
  /// Uses AppSettings.appLanguage as the source of truth
  @MainActor
  static var isRTL: Bool {
    AppSettings.appLanguage == .arabic
  }

  /// Determines if the current language preference is RTL (Right-to-Left)
  /// Uses AppSettings.appLanguage as the source of truth
  @MainActor
  static func isRTL(conversationLanguage: DetectedLanguage? = nil) -> Bool {
    // The app-wide setting overrides specific conversation settings for UI layout
    return AppSettings.appLanguage == .arabic
  }

  /// Returns the layout direction based on language preference
  @MainActor
  static var layoutDirection: LayoutDirection {
    isRTL ? .rightToLeft : .leftToRight
  }

  /// Returns the layout direction based on language preference
  @MainActor
  static func layoutDirection(conversationLanguage: DetectedLanguage? = nil) -> LayoutDirection {
    return isRTL(conversationLanguage: conversationLanguage) ? .rightToLeft : .leftToRight
  }

  /// Returns the current locale based on app language
  @MainActor
  static var locale: Locale {
    AppSettings.appLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
  }

  /// Converts a leading/trailing alignment to RTL-aware alignment
  static func rtlAwareAlignment(_ alignment: HorizontalAlignment, isRTL: Bool)
    -> HorizontalAlignment
  {
    guard isRTL else { return alignment }

    switch alignment {
    case .leading:
      return .trailing
    case .trailing:
      return .leading
    default:
      return alignment
    }
  }

  /// Converts a leading/trailing edge to RTL-aware edge
  static func rtlAwareEdge(_ edge: Edge, isRTL: Bool) -> Edge {
    guard isRTL else { return edge }

    switch edge {
    case .leading:
      return .trailing
    case .trailing:
      return .leading
    default:
      return edge
    }
  }

  /// Converts a leading/trailing text alignment to RTL-aware alignment
  static func rtlAwareTextAlignment(_ alignment: TextAlignment, isRTL: Bool) -> TextAlignment {
    guard isRTL else { return alignment }

    switch alignment {
    case .leading:
      return .trailing
    case .trailing:
      return .leading
    default:
      return alignment
    }
  }

  /// Returns RTL-aware padding for leading edge
  static func leadingPadding(_ value: CGFloat, isRTL: Bool) -> CGFloat {
    return isRTL ? 0 : value
  }

  /// Returns RTL-aware padding for trailing edge
  static func trailingPadding(_ value: CGFloat, isRTL: Bool) -> CGFloat {
    return isRTL ? value : 0
  }

  /// Returns RTL-aware alignment for frame
  static func rtlAwareFrameAlignment(_ alignment: Alignment, isRTL: Bool) -> Alignment {
    guard isRTL else { return alignment }

    switch alignment {
    case .leading:
      return .trailing
    case .trailing:
      return .leading
    case .topLeading:
      return .topTrailing
    case .topTrailing:
      return .topLeading
    case .bottomLeading:
      return .bottomTrailing
    case .bottomTrailing:
      return .bottomLeading
    default:
      return alignment
    }
  }

  /// Returns RTL-aware chevron icon name
  static func chevronIcon(isRTL: Bool) -> String {
    isRTL ? "chevron.left" : "chevron.right"
  }
}
