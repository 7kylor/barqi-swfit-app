import SwiftUI

struct BubbleContainer<Content: View>: View {
  let role: ChatMessage.Role
  private let content: () -> Content

  init(role: ChatMessage.Role, @ViewBuilder content: @escaping () -> Content) {
    self.role = role
    self.content = content
  }

  private var cornerRadius: CGFloat {
    role == .system ? Radius.md : Radius.lg
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
  }

  /// Enhanced tint color for glass effect based on role
  private var glassTint: Color {
    switch role {
    case .user:
      return Brand.bubbleUser
    case .assistant:
      return Brand.bubbleAssistant
    case .system:
      return Brand.bubbleSystem
    }
  }

  /// Padding based on role
  private var verticalPadding: CGFloat {
    role == .system ? Space.md : Space.lg
  }

  private var horizontalPadding: CGFloat {
    role == .system ? Space.md : Space.lg
  }

  /// Unified frame alignment: User bubbles always on right, assistant/system always on left
  /// This ensures consistent layout structure in both English and Arabic
  private var frameAlignment: Alignment {
    switch role {
    case .user:
      return .trailing
    case .assistant, .system:
      return .leading
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Space.xs) {
      content()
    }
    .padding(.vertical, verticalPadding)
    .padding(.horizontal, horizontalPadding)
    .bubbleGlassBackground(shape: shape, tint: glassTint)
    // Removed animation on appear to prevent flickering during scroll recycling
    .frame(maxWidth: Layout.bubbleMaxWidth, alignment: frameAlignment)
    .fixedSize(horizontal: false, vertical: true)
    // Keep layout direction LTR for consistent bubble positioning
    // Text alignment within bubbles is handled by individual components
    .environment(\.layoutDirection, .leftToRight)
  }
}

// MARK: - Bubble Glass Background Modifier
extension View {
  fileprivate func bubbleGlassBackground(shape: RoundedRectangle, tint: Color) -> some View {
    self
      .glassEffect(.regular.tint(tint), in: shape)
  }
}
