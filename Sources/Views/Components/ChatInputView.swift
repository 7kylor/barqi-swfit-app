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
      .animation(.interactiveSpring(), value: configuration.isPressed)
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
  @ObservedObject private var presetManager = PresetManager.shared

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: Space.sm) {
        textField
          .padding(.vertical, Space.sm)
          .padding(.horizontal, Space.md)
      }

      HStack(spacing: Space.sm) {
        Menu {
          ForEach(Preset.allCases) { preset in
            Button {
              presetManager.selectPreset(preset)
            } label: {
              Label(preset.displayName, systemImage: preset.icon)
            }
          }
        } label: {
          Image(systemName: presetManager.activePreset.icon)
            .font(.title2)
            .foregroundStyle(Brand.textPrimary)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Brand.surfaceElevated))
        }
        .buttonStyle(ScaleButtonStyle())

        Spacer()

        if isSending {
          Button(action: { onStop?() }) {
            Image(systemName: "stop.fill")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(width: 36, height: 36)
              .background(Circle().fill(Brand.error))
          }
        } else {
          Button(action: { handleSend() }) {
            Image(systemName: "arrow.up")
              .font(.headline.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 36, height: 36)
              .background(
                Circle().fill(text.isEmpty ? Brand.textSecondary.opacity(0.3) : Brand.primary))
          }
          .disabled(text.isEmpty)
        }
      }
      .padding(.horizontal, Space.md)
      .padding(.bottom, Space.md)
    }
    .background(Brand.surface.opacity(0.8).background(.ultraThinMaterial))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .padding(.horizontal, Space.md)
    .padding(.bottom, Space.sm)
  }

  private var textField: some View {
    TextField("Ask the Council...", text: $text, axis: .vertical)
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
