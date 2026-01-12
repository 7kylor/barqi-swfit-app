#if os(iOS)
import UIKit

/// Provides haptic feedback with graceful error handling for environments where haptics aren't available
@MainActor
enum HapticFeedback {
  /// Provides impact haptic feedback (light, medium, or heavy)
  static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    guard AppSettings.hapticsEnabled else { return }
    #if !targetEnvironment(simulator)
      // Skip haptic feedback in simulator to avoid hapticpatternlibrary.plist errors
      let generator = UIImpactFeedbackGenerator(style: style)
      generator.prepare()
      generator.impactOccurred()
    #endif
  }
  
  /// Provides notification haptic feedback (success, warning, or error)
  static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    guard AppSettings.hapticsEnabled else { return }
    #if !targetEnvironment(simulator)
      // Skip haptic feedback in simulator to avoid hapticpatternlibrary.plist errors
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(type)
    #endif
  }
  
  /// Provides selection haptic feedback (for picker changes, etc.)
  static func selection() {
    guard AppSettings.hapticsEnabled else { return }
    #if !targetEnvironment(simulator)
      // Skip haptic feedback in simulator to avoid hapticpatternlibrary.plist errors
      let generator = UISelectionFeedbackGenerator()
      generator.prepare()
      generator.selectionChanged()
    #endif
  }
}

#else

// macOS stub - haptics not available
@MainActor
enum HapticFeedback {
  enum FeedbackStyle {
    case light, medium, heavy, soft, rigid
  }
  
  enum FeedbackType {
    case success, warning, error
  }
  
  static func impact(style: FeedbackStyle = .light) {
    // No-op on macOS
  }
  
  static func notification(_ type: FeedbackType) {
    // No-op on macOS
  }
  
  static func selection() {
    // No-op on macOS
  }
}

#endif
