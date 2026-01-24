import Combine
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

// MARK: - Helper Styles
struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
      .animation(.snappy(duration: 0.2), value: configuration.isPressed)
  }
}

@MainActor
struct ChatInputView: View {
  @Binding var text: String
  let isSending: Bool
  let onSend: () -> Void
  var onStop: (() -> Void)? = nil
  var isFocused: FocusState<Bool>.Binding
  @Namespace private var animationNamespace

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: Space.sm) {
        textField
          .padding(.vertical, Space.sm)
          .padding(.horizontal, Space.md)
      }

      HStack(spacing: Space.sm) {
        Spacer()

        if isSending {
          Button(action: { onStop?() }) {
            Image(systemName: "stop.fill")
              .font(TypeScale.headline)
              .foregroundStyle(.white)
              .frame(width: 36, height: 36)
              .background(Circle().fill(Brand.error))
          }
          .buttonStyle(ScaleButtonStyle())
        } else {
          Button(action: { handleSend() }) {
            Image(systemName: "arrow.up")
              .font(TypeScale.headline.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 36, height: 36)
              .background(
                Circle().fill(text.isEmpty ? Brand.textSecondary.opacity(0.3) : Brand.primary))
          }
          .disabled(text.isEmpty)
          .buttonStyle(ScaleButtonStyle())
        }
      }
      .padding(.horizontal, Space.md)
      .padding(.bottom, Space.md)
    }
    .liquidGlass(cornerRadius: Radius.xl)
    .padding(.horizontal, Space.md)
    .padding(.bottom, Space.sm)
  }

  private var textField: some View {
    TextField(L("ask_the_council"), text: $text, axis: .vertical)
      .font(TypeScale.body)
      .focused(isFocused)
      .lineLimit(1...5)
      .submitLabel(.send)
      .onSubmit { handleSend() }
  }

  private func handleSend() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onSend()
  }
}
