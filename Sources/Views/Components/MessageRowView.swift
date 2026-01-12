import SwiftUI

@MainActor
struct MessageRowView: View {
  let message: ChatMessage
  let isLatest: Bool
  let isGeneratingLatest: Bool
  let onRetry: () -> Void
  var onSpeak: ((ChatMessage) -> Void)? = nil
  var speakingMessageId: UUID? = nil
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    // Unified layout: User messages always on right (trailing), assistant always on left (leading)
    // This ensures the same layout structure in both English and Arabic
    // Only text alignment within bubbles changes based on language
    let userAlignment: HorizontalAlignment = .trailing
    let assistantAlignment: HorizontalAlignment = .leading
    let rowAlignment: Alignment = message.role == .user ? .trailing : .leading
    
    VStack(alignment: message.role == .user ? userAlignment : assistantAlignment, spacing: Space.xs) {
      // Main message content with enhanced spacing
      switch message.role {
      case .user:
        VStack(alignment: userAlignment, spacing: Space.xs) {
          ChatBubble(message: message, isGeneratingLatest: isGeneratingLatest)
          messageMetadata
        }
      case .assistant:
        VStack(alignment: assistantAlignment, spacing: Space.xs) {
          AssistantMessageView(
            message: message,
            isLatest: isLatest,
            isGeneratingLatest: isGeneratingLatest,
            onRetry: onRetry,
            onSpeak: onSpeak,
            isSpeaking: speakingMessageId == message.id
          )
          messageMetadata
        }
      case .system:
        VStack(alignment: assistantAlignment, spacing: Space.xs) {
          ChatBubble(message: message, isGeneratingLatest: isGeneratingLatest)
          messageMetadata
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: rowAlignment)
    .padding(.vertical, message.role == .system ? Space.xs : Space.sm)
    // Keep layout direction LTR for consistent bubble positioning
    // Text alignment within bubbles is handled by individual components
    .environment(\.layoutDirection, .leftToRight)
    .animation(reduceMotion ? nil : AnimationUtilities.smooth, value: shouldShowTimestamp)
  }
  
  // MARK: - Message Metadata
  
  @ViewBuilder
  private var messageMetadata: some View {
    // Only show timestamp when message is fully generated (same condition as action buttons)
    if shouldShowTimestamp {
      metadataLine
        .padding(.top, Space.xs + 2)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
    }
  }
  
  @ViewBuilder
  private var metadataLine: some View {
    HStack(spacing: Space.xs) {
      Text(AppFormatters.shortTimeOnly.string(from: message.createdAt))
        .monospacedDigit()
      
      if message.role == .assistant, let tps = message.tokensPerSecond, tps > 0 {
        Text("•")
          .foregroundStyle(Brand.textSecondary.opacity(0.5))
        Text(L("tokens_per_sec", String(format: "%.1f", tps)))
          .monospacedDigit()
      }
    }
    .font(TypeScale.caption2)
    .fontWeight(.regular)
    .foregroundStyle(Brand.textSecondary.opacity(0.7))
    .tracking(0.2)
  }
  
  /// Determines if timestamp should be shown - only after message is fully generated
  private var shouldShowTimestamp: Bool {
    switch message.role {
    case .assistant:
      // For assistant messages: show when not thinking and not generating (same as action buttons)
      let isAssistantThinking = message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      let isGenerating = isLatest && isGeneratingLatest
      return !isAssistantThinking && !isGenerating
    case .user:
      // For user messages: show when not generating
      return !isGeneratingLatest
    case .system:
      // System messages always show timestamp
      return true
    }
  }
}
