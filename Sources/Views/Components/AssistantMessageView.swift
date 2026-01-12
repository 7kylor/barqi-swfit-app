import Foundation
import SwiftUI

struct AssistantMessageView: View {
  let message: ChatMessage
  var isLatest: Bool = false
  var isGeneratingLatest: Bool = false
  var onRetry: (() -> Void)? = nil
  var onSpeak: ((ChatMessage) -> Void)? = nil
  var isSpeaking: Bool = false

  @State private var showShare: Bool = false
  @State private var didCopy: Bool = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Keeps bubble positioning stable (handled by parent), while letting the text flow naturally
  /// for Arabic/English *inside* the assistant message content.
  private var contentLayoutDirection: LayoutDirection {
    switch message.language {
    case .arabic:
      return .rightToLeft
    case .english:
      return .leftToRight
    case .unknown, nil:
      return RTLUtilities.layoutDirection
    }
  }

  var body: some View {
    // Unified layout: Always use leading alignment for consistent structure
    // Text alignment within bubbles changes based on language
    VStack(alignment: .leading, spacing: Space.xs) {
      Group {
        if isAssistantThinking {
          // Thinking indicator maintains same alignment as completed message
          ThinkingIndicator()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.sm)
        } else {
          // MarkdownText maintains consistent container alignment (leading) for unified layout
          // Text alignment within changes based on language, but container stays aligned
          MarkdownText(
            text: LanguageDetector.localizePunctuationIfNeeded(
              LanguageDetector.shapeArabicNumeralsIfNeeded(
                text: TextSanitizer.sanitizeAssistantText(message.text),
                language: message.language
              ),
              language: message.language
            ),
            font: TypeScale.body,
            textAlignment: .leading,
            layoutDirection: contentLayoutDirection,
            lineSpacing: 2
          )
          .accessibilityLabel(L("assistant_message"))
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      if let reasoning = message.reasoning,
        !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        ReasoningDisclosure(text: reasoning, layoutDirection: contentLayoutDirection)
          .accessibilityLabel(L("assistant_reasoning_details"))
          .padding(.horizontal, Space.sm)
      }

      if !isAssistantThinking && !isGenerating {
        HStack(spacing: Space.xs) {
          // Speak button with glass effect
          Button {
            HapticFeedback.selection()
            onSpeak?(message)
          } label: {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
              .font(TypeScale.caption)
              .fontWeight(.medium)
              .foregroundStyle(isSpeaking ? Brand.primary : Brand.textSecondary)
              .frame(width: 32, height: 32)
              .liquidGlassCircle(tintColor: isSpeaking ? Brand.primary.opacity(0.1) : nil)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isSpeaking ? L("stop_speaking") : L("speak_message"))
          .accessibilityHint(L("reads_message_aloud"))

          // Copy button with glass effect
          Button {
            copyToPasteboard(message.text)
            HapticFeedback.selection()
            if !reduceMotion {
              withAnimation(AnimationUtilities.instant) {
                didCopy = true
              }
            } else {
              didCopy = true
            }
            Task { @MainActor in
              try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
              if !reduceMotion {
                withAnimation(AnimationUtilities.instant) { didCopy = false }
              } else {
                didCopy = false
              }
            }
          } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
              .font(TypeScale.caption)
              .fontWeight(.medium)
              .foregroundStyle(didCopy ? Brand.success : Brand.textSecondary)
              .frame(width: 32, height: 32)
              .liquidGlassCircle(tintColor: didCopy ? Brand.success.opacity(0.1) : nil)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L("copy"))
          .accessibilityHint(L("copies_assistant_message"))

          // Share button with glass effect
          Button {
            HapticFeedback.selection()
            showShare = true
          } label: {
            Image(systemName: "square.and.arrow.up")
              .font(TypeScale.caption)
              .fontWeight(.medium)
              .foregroundStyle(Brand.textSecondary)
              .frame(width: 32, height: 32)
              .liquidGlassCircle()
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L("share"))
          .accessibilityHint(L("opens_share_sheet"))

          // Retry button with glass effect
          if isLatest && !isAssistantThinking {
            Button {
              HapticFeedback.selection()
              onRetry?()
            } label: {
              Image(systemName: "arrow.clockwise")
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(Brand.textSecondary)
                .frame(width: 32, height: 32)
                .liquidGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("retry"))
            .accessibilityHint(L("regenerates_response"))
          }

          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.xs)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
      }
    }
    // Constrain assistant content width so Arabic (RTL) text doesn't "jump" to the far right edge.
    .frame(maxWidth: Layout.bubbleMaxWidth, alignment: .leading)
    // Removed horizontal padding to ensure flush left alignment
    // Keep layout direction LTR for consistent bubble positioning
    // Text flow direction inside content is handled per-message (see contentLayoutDirection)
    .environment(\.layoutDirection, .leftToRight)
    #if os(iOS)
      .sheet(isPresented: $showShare) {
        ActivityView(activityItems: [message.text] as [ActivityItemProviding])
      }
    #endif
    .animation(
      reduceMotion ? nil : AnimationUtilities.smooth, value: !isAssistantThinking && !isGenerating)
  }

  private var isAssistantThinking: Bool {
    message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var isGenerating: Bool {
    isLatest && isGeneratingLatest
  }
}

private func copyToPasteboard(_ text: String) {
  #if os(iOS)
    UIPasteboard.general.string = text
  #endif
}

#if os(iOS)
  import UIKit

  private protocol ActivityItemProviding {
    var activityItem: Any { get }
  }

  extension String: ActivityItemProviding {
    var activityItem: Any { self }
  }

  private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [ActivityItemProviding]

    func makeUIViewController(context: Context) -> UIActivityViewController {
      UIActivityViewController(
        activityItems: activityItems.map { $0.activityItem },
        applicationActivities: nil
      )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
  }
#endif
