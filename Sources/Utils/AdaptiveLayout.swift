import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

// MARK: - Device Type Detection

/// Detects the current device type for adaptive layouts
enum DeviceType: Sendable {
  case iPhone
  case iPad
  case mac

  /// Compile-time platform detection (use environment for runtime size class)
  static var current: DeviceType {
    #if os(macOS)
      return .mac
    #elseif os(iOS)
      // Use compile-time check for iPad vs iPhone target
      // For runtime size class detection, use @Environment(\.horizontalSizeClass)
      #if targetEnvironment(macCatalyst)
        return .mac
      #else
        // Default to iPad for larger layouts - actual size class should be checked at runtime
        return .iPad
      #endif
    #else
      return .iPhone
    #endif
  }

  /// Runtime device type detection (must be called on main actor)
  @MainActor
  static var runtimeCurrent: DeviceType {
    #if os(macOS)
      return .mac
    #elseif os(iOS)
      if UIDevice.current.userInterfaceIdiom == .pad {
        return .iPad
      }
      return .iPhone
    #else
      return .iPhone
    #endif
  }

  var isCompact: Bool {
    self == .iPhone
  }

  var isWide: Bool {
    self == .iPad || self == .mac
  }
}

// MARK: - Size Class Environment

/// Environment key for horizontal size class detection
struct HorizontalSizeClassKey: EnvironmentKey {
  static let defaultValue: UserInterfaceSizeClass? = nil
}

// MARK: - Adaptive Layout Constants

/// Platform-adaptive layout constants following Apple HIG
enum AdaptiveLayout {

  // MARK: - Spacing

  /// Minimum spacing for the current platform
  static var minSpacing: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 8
    case .iPad: return 12
    case .mac: return 10
    }
  }

  /// Standard spacing for the current platform
  static var standardSpacing: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 16
    case .iPad: return 20
    case .mac: return 16
    }
  }

  /// Large spacing for the current platform
  static var largeSpacing: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 24
    case .iPad: return 32
    case .mac: return 24
    }
  }

  // MARK: - Content Width

  /// Maximum content width for readable content
  static var maxReadableWidth: CGFloat {
    switch DeviceType.current {
    case .iPhone: return .infinity
    case .iPad: return 720
    case .mac: return 800
    }
  }

  /// Sidebar width for split view
  static var sidebarWidth: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 0
    case .iPad: return 320
    case .mac: return 280
    }
  }

  /// Detail view minimum width
  static var detailMinWidth: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 0
    case .iPad: return 400
    case .mac: return 450
    }
  }

  // MARK: - Grid Layout

  /// Number of columns for grid layouts based on available width
  static func gridColumns(for width: CGFloat) -> Int {
    switch DeviceType.current {
    case .iPhone:
      return width > 500 ? 3 : 2
    case .iPad:
      if width > 1000 { return 4 }
      if width > 700 { return 3 }
      return 2
    case .mac:
      if width > 1200 { return 5 }
      if width > 900 { return 4 }
      if width > 600 { return 3 }
      return 2
    }
  }

  /// Grid item minimum width
  static var gridItemMinWidth: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 150
    case .iPad: return 180
    case .mac: return 200
    }
  }

  // MARK: - Touch/Click Targets

  /// Minimum interactive target size (following HIG)
  static var minTapTargetSize: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 44
    case .iPad: return 44
    case .mac: return 24  // Mac uses pointer, smaller targets OK
    }
  }

  /// Button height
  static var buttonHeight: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 50
    case .iPad: return 54
    case .mac: return 32
    }
  }

  /// Large button height (primary actions)
  static var largeButtonHeight: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 56
    case .iPad: return 60
    case .mac: return 44
    }
  }

  // MARK: - Corner Radius

  /// Standard corner radius
  static var cornerRadius: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 12
    case .iPad: return 16
    case .mac: return 8
    }
  }

  /// Large corner radius
  static var largeCornerRadius: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 20
    case .iPad: return 24
    case .mac: return 12
    }
  }

  // MARK: - Typography Scale

  /// Title font size multiplier
  static var titleScale: CGFloat {
    switch DeviceType.current {
    case .iPhone: return 1.0
    case .iPad: return 1.15
    case .mac: return 1.0
    }
  }

  // MARK: - Navigation

  /// Whether to use sidebar navigation
  static var usesSidebarNavigation: Bool {
    DeviceType.current != .iPhone
  }

  /// Whether to show toolbar items inline
  static var showsInlineToolbar: Bool {
    DeviceType.current == .mac
  }
}

// MARK: - Adaptive View Modifiers

extension View {
  /// Apply platform-adaptive frame with maximum readable width
  func adaptiveReadableWidth() -> some View {
    self.frame(maxWidth: AdaptiveLayout.maxReadableWidth)
  }

  /// Apply platform-adaptive padding
  func adaptivePadding(_ edges: Edge.Set = .all) -> some View {
    self.padding(edges, AdaptiveLayout.standardSpacing)
  }

  /// Apply platform-adaptive spacing in stacks
  func adaptiveSpacing() -> some View {
    self.padding(.vertical, AdaptiveLayout.minSpacing)
  }

  /// Conditionally apply modifier based on platform
  @ViewBuilder
  func ifPlatform(_ platform: DeviceType, apply modifier: (Self) -> some View) -> some View {
    if DeviceType.current == platform {
      modifier(self)
    } else {
      self
    }
  }

  /// Apply different modifiers based on platform
  @ViewBuilder
  func onPlatform<V: View>(
    iPhone: ((Self) -> V)? = nil,
    iPad: ((Self) -> V)? = nil,
    mac: ((Self) -> V)? = nil
  ) -> some View {
    switch DeviceType.current {
    case .iPhone:
      if let modify = iPhone {
        modify(self)
      } else {
        self
      }
    case .iPad:
      if let modify = iPad {
        modify(self)
      } else {
        self
      }
    case .mac:
      if let modify = mac {
        modify(self)
      } else {
        self
      }
    }
  }

  /// Apply hover effect on Mac, highlight on iOS
  func adaptiveInteraction() -> some View {
    #if os(macOS)
      self.onHover { hovering in
        if hovering {
          NSCursor.pointingHand.push()
        } else {
          NSCursor.pop()
        }
      }
    #else
      self.hoverEffect(.highlight)
    #endif
  }
}

// MARK: - Adaptive Grid

/// Adaptive grid that adjusts columns based on available space
struct AdaptiveGrid<Content: View>: View {
  let content: Content
  let minItemWidth: CGFloat
  let spacing: CGFloat

  init(
    minItemWidth: CGFloat = AdaptiveLayout.gridItemMinWidth,
    spacing: CGFloat = Space.md,
    @ViewBuilder content: () -> Content
  ) {
    self.minItemWidth = minItemWidth
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    GeometryReader { geometry in
      let columns = max(1, Int(geometry.size.width / minItemWidth))
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
        spacing: spacing
      ) {
        content
      }
    }
  }
}

// MARK: - Responsive Container

/// Container that adapts its layout based on horizontal size class
struct ResponsiveContainer<Compact: View, Regular: View>: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  let compact: () -> Compact
  let regular: () -> Regular

  init(
    @ViewBuilder compact: @escaping () -> Compact,
    @ViewBuilder regular: @escaping () -> Regular
  ) {
    self.compact = compact
    self.regular = regular
  }

  var body: some View {
    if horizontalSizeClass == .compact {
      compact()
    } else {
      regular()
    }
  }
}

// MARK: - Platform Container

/// Container that shows different content based on platform
struct PlatformContainer<IPhone: View, IPad: View, Mac: View>: View {
  let iPhone: () -> IPhone
  let iPad: () -> IPad
  let mac: () -> Mac

  init(
    @ViewBuilder iPhone: @escaping () -> IPhone,
    @ViewBuilder iPad: @escaping () -> IPad,
    @ViewBuilder mac: @escaping () -> Mac
  ) {
    self.iPhone = iPhone
    self.iPad = iPad
    self.mac = mac
  }

  var body: some View {
    switch DeviceType.current {
    case .iPhone:
      iPhone()
    case .iPad:
      iPad()
    case .mac:
      mac()
    }
  }
}

// MARK: - Window Size Reader

/// Reads and provides the current window/scene size
struct WindowSizeReader<Content: View>: View {
  @ViewBuilder let content: (CGSize) -> Content

  var body: some View {
    GeometryReader { geometry in
      content(geometry.size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - Keyboard Shortcut Helpers

extension View {
  /// Add common keyboard shortcuts for the app
  func withAppKeyboardShortcuts(
    onNewChat: @escaping () -> Void,
    onSettings: (() -> Void)? = nil,
    onSearch: (() -> Void)? = nil
  ) -> some View {
    self
      .onKeyPress(keys: [KeyEquivalent("n")], phases: .down) { keyPress in
        if keyPress.modifiers.contains(.command) {
          onNewChat()
          return .handled
        }
        return .ignored
      }
  }
}

// MARK: - macOS Specific Helpers

#if os(macOS)
  extension NSWindow {
    /// Configure window for Mawj app appearance
    func configureMawjAppearance() {
      titlebarAppearsTransparent = true
      styleMask.insert(.fullSizeContentView)
      backgroundColor = .windowBackgroundColor
      minSize = NSSize(width: 600, height: 400)
    }
  }
#endif

// MARK: - iPad Multitasking Support

#if os(iOS)
  /// Check if app is running in Split View or Slide Over
  @MainActor
  var isMultitasking: Bool {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    else {
      return false
    }
    return window.frame.width < windowScene.screen.bounds.width
  }

  /// Check if app is in Stage Manager
  @MainActor
  var isInStageManager: Bool {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
      return false
    }
    // Stage Manager allows resizable windows
    return windowScene.windows.first?.windowScene?.sizeRestrictions != nil
  }
#endif
