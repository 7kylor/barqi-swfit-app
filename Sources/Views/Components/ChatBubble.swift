import SwiftUI

struct ChatBubble: View {
  let message: ChatMessage
  let isGeneratingLatest: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    BubbleContainer(role: message.role) {
      // Header for system messages with improved styling
      if message.role == .system {
        HStack(spacing: Space.xs) {
          Image(systemName: "gear.badge")
            .font(TypeScale.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Brand.textSecondary)
          Text(L("system"))
            .font(TypeScale.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Brand.textSecondary)
            .textCase(.uppercase)
        }
        .padding(.bottom, Space.xs)
      }

      // Message content with enhanced typography
      VStack(alignment: .leading, spacing: Space.xs) {
        Text(
          LanguageDetector.localizePunctuationIfNeeded(
            LanguageDetector.shapeArabicNumeralsIfNeeded(
              text: message.text, language: message.language),
            language: message.language
          )
        )
        .textSelection(.enabled)
        .font(message.role == .system ? TypeScale.subhead : TypeScale.body)
        .foregroundStyle(message.role == .system ? Brand.textSecondary : Brand.textPrimary)
        .multilineTextAlignment(.leading)
        .lineSpacing(message.role == .system ? 2 : 4)
        // Let the Text flow naturally for Arabic/English without affecting bubble positioning.
        .environment(\.layoutDirection, textLayoutDirection)
        .fixedSize(horizontal: false, vertical: true)

        // Generating indicator for user messages (if needed)
        // Maintains same alignment as message content for consistency
        if message.role == .user && isGeneratingLatest {
          generatingIndicator
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    }
    // Removed DragGesture and scale effect to prevent flickering during scroll
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
    .accessibilityHint(accessibilityHintText)
  }

  // MARK: - Generating Indicator

  @ViewBuilder
  private var generatingIndicator: some View {
    HStack(spacing: Space.xs) {
      ForEach(0..<3) { index in
        Circle()
          .frame(width: 4, height: 4)
          .foregroundStyle(Brand.primary.opacity(0.6))
          .scaleEffect(isGeneratingLatest ? 1.0 : 0.7)
          .opacity(isGeneratingLatest ? 1.0 : 0.5)
          .animation(
            reduceMotion
              ? nil
              : .spring(response: 0.25, dampingFraction: 0.8)
                .repeatForever()
                .delay(Double(index) * 0.1),
            value: isGeneratingLatest
          )
      }
    }
    .padding(.top, Space.xs)
  }

  // MARK: - Computed Properties

  private var textLayoutDirection: LayoutDirection {
    switch message.language {
    case .arabic:
      return .rightToLeft
    case .english:
      return .leftToRight
    case .unknown, nil:
      return RTLUtilities.layoutDirection
    }
  }

  private var accessibilityText: String {
    let prefix: String
    switch message.role {
    case .user: prefix = L("message_from_you") + ", "
    case .assistant: prefix = L("message_from_assistant") + ", "
    case .system: prefix = L("message_from_system") + ", "
    }
    return prefix + message.text
  }

  private var accessibilityHintText: String {
    switch message.role {
    case .user: return L("your_message")
    case .assistant: return L("assistant_message")
    case .system: return L("system_message")
    }
  }
}
