import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Shared spacing scale following modern iOS/macOS/iPadOS layout guidelines
/// Adapts automatically based on platform following Apple HIG
enum Space {
  static var xs: CGFloat {
    #if os(macOS)
    return 3
    #else
    return 4
    #endif
  }
  
  static var sm: CGFloat {
    #if os(macOS)
    return 6
    #else
    return 8
    #endif
  }
  
  static var md: CGFloat {
    #if os(macOS)
    return 10
    #else
    return 12
    #endif
  }
  
  static var lg: CGFloat {
    #if os(macOS)
    return 14
    #else
    return 16
    #endif
  }
  
  static var xl: CGFloat {
    #if os(macOS)
    return 20
    #else
    return 24
    #endif
  }
  
  static var xxl: CGFloat {
    #if os(macOS)
    return 28
    #else
    return 32
    #endif
  }
}

/// Shared corner radius tokens for consistent shapes
/// macOS uses smaller radii following Apple HIG
enum Radius {
  static var sm: CGFloat {
    #if os(macOS)
    return 6
    #else
    return 8
    #endif
  }
  
  static var md: CGFloat {
    #if os(macOS)
    return 8
    #else
    return 12
    #endif
  }
  
  static var lg: CGFloat {
    #if os(macOS)
    return 12
    #else
    return 16
    #endif
  }
  
  static var xl: CGFloat {
    #if os(macOS)
    return 16
    #else
    return 20
    #endif
  }
  
  static var xxl: CGFloat {
    #if os(macOS)
    return 20
    #else
    return 24
    #endif
  }
}

/// Layout constants for consistent sizing constraints
@MainActor
enum Layout {
  // Constrain bubble width to a comfortable reading measure; updated at runtime by screen size
  static var bubbleMaxWidth: CGFloat {
    #if os(iOS)
      // Get UIScreen from window scene context (iOS 26.0+ compatible)
      let width: CGFloat = {
        var w: CGFloat = 420
        if Thread.isMainThread {
          if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            w = windowScene.screen.bounds.width
          }
        } else {
          w = MainActor.assumeIsolated {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
              return windowScene.screen.bounds.width
            }
            return 420
          }
        }
        return w
      }()
      // Keep bubbles at most ~85% of screen width on phones; larger on iPad
      let isIPad = UIDevice.current.userInterfaceIdiom == .pad
      if isIPad {
        return min(700, max(400, width * 0.7))
      }
      return min(520, max(280, width * 0.85))
    #elseif os(macOS)
      // macOS: wider bubbles for desktop reading
      return 680
    #else
      return 520
    #endif
  }
  
  /// Sidebar width for split view layouts
  static var sidebarWidth: CGFloat {
    #if os(macOS)
    return 280
    #else
    return 320
    #endif
  }
  
  /// Minimum detail view width
  static var detailMinWidth: CGFloat {
    #if os(macOS)
    return 450
    #else
    return 400
    #endif
  }
  
  /// Maximum readable content width
  static var maxReadableWidth: CGFloat {
    #if os(macOS)
    return 800
    #else
    return 720
    #endif
  }
  
  /// Standard toolbar button size
  static var toolbarButtonSize: CGFloat {
    #if os(macOS)
    return 28
    #else
    return 32
    #endif
  }
}

/// Typography tokens that map to Dynamic Type-aware system styles
enum TypeScale {
  static let largeTitle: Font = .largeTitle
  static let title2: Font = .title2
  static let title: Font = .title3
  static let headline: Font = .headline
  static let subhead: Font = .subheadline
  static let footnote: Font = .footnote
  static let body: Font = .body
  static let caption: Font = .caption
  static let caption2: Font = .caption2
}

/// Brand and surface colors tuned for light/dark modes across all Apple platforms
enum Brand {
  /// App icon blue brand primary (#0D47A1)
  static let primary: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 0.051, green: 0.278, blue: 0.631, alpha: 1.0)
          : UIColor(red: 0.051, green: 0.278, blue: 0.631, alpha: 1.0)
      }
    )
    #elseif os(macOS)
    return Color(red: 0.051, green: 0.278, blue: 0.631)
    #else
    return Color(red: 0.051, green: 0.278, blue: 0.631)
    #endif
  }()

  /// Accent color alias
  static let accent: Color = primary

  static let surface: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor.secondarySystemBackground : UIColor.systemBackground
      }
    )
    #elseif os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #else
    return Color(.systemBackground)
    #endif
  }()

  static let secondarySurface: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor.tertiarySystemBackground : UIColor.secondarySystemBackground
      }
    )
    #elseif os(macOS)
    return Color(NSColor.controlBackgroundColor)
    #else
    return Color(.secondarySystemBackground)
    #endif
  }()

  /// Elevated card-like surface
  static let surfaceElevated: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(white: 0.10, alpha: 1.0)
          : UIColor(white: 1.0, alpha: 1.0)
      }
    )
    #elseif os(macOS)
    return Color(NSColor.controlBackgroundColor)
    #else
    return Color(white: 1.0)
    #endif
  }()

  static let fieldBackground: Color = {
    #if os(iOS)
    return Color(UIColor.tertiarySystemFill)
    #elseif os(macOS)
    return Color(NSColor.controlBackgroundColor)
    #else
    return Color(.tertiarySystemFill)
    #endif
  }()

  /// App icon blue for user bubble glass effect tint
  static let bubbleUser: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 0.051, green: 0.278, blue: 0.631, alpha: 0.3)
          : UIColor(red: 0.051, green: 0.278, blue: 0.631, alpha: 0.25)
      }
    )
    #elseif os(macOS)
    return Color(red: 0.051, green: 0.278, blue: 0.631).opacity(0.25)
    #else
    return Color(red: 0.051, green: 0.278, blue: 0.631).opacity(0.25)
    #endif
  }()

  /// Neutral color for assistant bubble glass effect (no tint)
  static let bubbleAssistant: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(white: 0.16, alpha: 0.3)
          : UIColor(white: 0.97, alpha: 0.3)
      }
    )
    #elseif os(macOS)
    return Color.gray.opacity(0.15)
    #else
    return Color.gray.opacity(0.15)
    #endif
  }()

  /// Neutral color for system bubble glass effect
  static let bubbleSystem: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(white: 0.16, alpha: 0.2)
          : UIColor(white: 0.97, alpha: 0.2)
      }
    )
    #elseif os(macOS)
    return Color.gray.opacity(0.1)
    #else
    return Color.gray.opacity(0.1)
    #endif
  }()

  static let textPrimary: Color = .primary
  static let textSecondary: Color = .secondary

  /// Success/positive color for confirmations and trial badges
  static let success: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
          : UIColor(red: 0.2, green: 0.65, blue: 0.32, alpha: 1.0)
      }
    )
    #elseif os(macOS)
    return Color(red: 0.2, green: 0.7, blue: 0.32)
    #else
    return Color(red: 0.2, green: 0.7, blue: 0.32)
    #endif
  }()

  /// Warning color for attention states
  static let warning: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
          : UIColor(red: 0.9, green: 0.7, blue: 0.0, alpha: 1.0)
      }
    )
    #elseif os(macOS)
    return Color(red: 0.95, green: 0.75, blue: 0.0)
    #else
    return Color(red: 0.95, green: 0.75, blue: 0.0)
    #endif
  }()

  /// Error/destructive color
  static let error: Color = {
    #if os(iOS)
    return Color(
      UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
          : UIColor(red: 0.9, green: 0.22, blue: 0.2, alpha: 1.0)
      }
    )
    #elseif os(macOS)
    return Color(red: 0.95, green: 0.25, blue: 0.22)
    #else
    return Color(red: 0.95, green: 0.25, blue: 0.22)
    #endif
  }()
}

// Disable expensive shadows in Low Power Mode
struct LowPowerShadow: ViewModifier {
  let color: Color
  func body(content: Content) -> some View {
    #if os(iOS)
      if ProcessInfo.processInfo.isLowPowerModeEnabled {
        content
      } else {
        content.shadow(color: color, radius: 1, y: 1)
      }
    #elseif os(macOS)
      // macOS: Use subtle shadows appropriate for desktop
      content.shadow(color: color.opacity(0.5), radius: 0.5, y: 0.5)
    #else
      content.shadow(color: color, radius: 1, y: 1)
    #endif
  }
}

// MARK: - Platform-specific Control Sizes

extension View {
  /// Apply platform-appropriate control size
  func adaptiveControlSize() -> some View {
    #if os(macOS)
    self.controlSize(.regular)
    #else
    self
    #endif
  }
  
  /// Apply platform-appropriate button style for primary actions
  func adaptivePrimaryButtonStyle() -> some View {
    #if os(macOS)
    self.buttonStyle(.borderedProminent)
    #else
    self
    #endif
  }
}
