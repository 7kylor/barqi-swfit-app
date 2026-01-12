import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

// MARK: - Platform-Optimized Chat Container

/// Container that wraps ChatView with platform-specific optimizations
/// Maintains iOS core while enhancing macOS and iPadOS experience
struct PlatformChatContainer: View {
  let conversation: Conversation

  var body: some View {
    ChatView(conversation: conversation)
      .platformChatStyling()
  }
}

extension View {
  func platformChatStyling() -> some View {
    self.modifier(PlatformChatStylingModifier())
  }
}

struct PlatformChatStylingModifier: ViewModifier {
  #if os(macOS)
    func body(content: Content) -> some View {
      content
        .frame(maxWidth: Layout.maxReadableWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AdaptiveLayout.standardSpacing)
    }
  #elseif os(iOS)
    @MainActor
    func body(content: Content) -> some View {
      if DeviceType.runtimeCurrent == .iPad {
        content
          .frame(maxWidth: Layout.maxReadableWidth)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, AdaptiveLayout.standardSpacing)
      } else {
        content
      }
    }
  #else
    func body(content: Content) -> some View {
      content
    }
  #endif
}
