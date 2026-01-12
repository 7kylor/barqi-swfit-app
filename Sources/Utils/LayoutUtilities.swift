import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Applies the "Liquid Glass" effect using iOS 26+, iPadOS 26+, and macOS 26+ native API.
/// Works seamlessly across all Apple platforms with platform-adaptive corner radii.
struct LiquidGlass: ViewModifier {
  let cornerRadius: CGFloat
  let tintColor: Color?

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    if let tint = tintColor {
      content
        .glassEffect(.regular.tint(tint), in: shape)
    } else {
      content
        .glassEffect(.regular, in: shape)
    }
  }
}

/// Capsule-shaped Liquid Glass effect for pill-shaped elements
struct LiquidGlassCapsule: ViewModifier {
  let tintColor: Color?

  func body(content: Content) -> some View {
    if let tint = tintColor {
      content
        .glassEffect(.regular.tint(tint), in: Capsule(style: .continuous))
    } else {
      content
        .glassEffect(.regular, in: Capsule(style: .continuous))
    }
  }
}

/// Circle-shaped Liquid Glass effect for circular buttons
struct LiquidGlassCircle: ViewModifier {
  let tintColor: Color?

  func body(content: Content) -> some View {
    if let tint = tintColor {
      content
        .glassEffect(.regular.tint(tint), in: Circle())
    } else {
      content
        .glassEffect(.regular, in: Circle())
    }
  }
}

extension View {
  /// Applies a liquid glass effect with a specified corner radius and optional tint.
  /// Default corner radius is platform-adaptive (16pt iOS/iPadOS, 12pt macOS).
  func liquidGlass(
    cornerRadius: CGFloat? = nil,
    tintColor: Color? = nil
  ) -> some View {
    let defaultRadius: CGFloat = {
      #if os(macOS)
        return Radius.lg  // 12pt for macOS
      #else
        return Radius.lg  // 16pt for iOS/iPadOS
      #endif
    }()

    return self.modifier(
      LiquidGlass(
        cornerRadius: cornerRadius ?? defaultRadius,
        tintColor: tintColor
      ))
  }

  /// Applies a capsule-shaped liquid glass effect (pill shape).
  func liquidGlassCapsule(
    tintColor: Color? = nil
  ) -> some View {
    self.modifier(LiquidGlassCapsule(tintColor: tintColor))
  }

  /// Applies a circle-shaped liquid glass effect.
  func liquidGlassCircle(
    tintColor: Color? = nil
  ) -> some View {
    self.modifier(LiquidGlassCircle(tintColor: tintColor))
  }

  /// Applies liquid glass effect to any InsettableShape.
  func liquidGlass<S: InsettableShape>(
    in shape: S,
    tintColor: Color? = nil
  ) -> some View {
    if let tint = tintColor {
      self.glassEffect(.regular.tint(tint), in: shape)
    } else {
      self.glassEffect(.regular, in: shape)
    }
  }
}
