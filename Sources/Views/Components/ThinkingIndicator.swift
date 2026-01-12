import Combine
import SwiftUI

/// Modern thinking indicator with Apple 2025-2026 design language
struct ThinkingIndicator: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var step: Int = 0
  private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
  var isAnimating: Bool = true

  var body: some View {
    // Maintains consistent alignment with message content
    HStack(spacing: Space.xs) {
      ForEach(0..<3) { index in
        Circle()
          .frame(width: 6, height: 6)
          .scaleEffect(step == index ? 1.0 : 0.6)
          .opacity(step == index ? 1.0 : 0.4)
          .foregroundStyle(Brand.primary)
          .animation(
            AnimationUtilities.responsive
              .delay(Double(index) * 0.1),
            value: step
          )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityLabel(L("assistant_thinking"))
    .accessibilityHint(L("generating_response"))
    .accessibilityAddTraits(.updatesFrequently)
    .onReceive(tick) { _ in
      guard isAnimating && scenePhase == .active else { return }
      step = (step + 1) % 3
    }
  }
}

/// Typing indicator for user input state
struct TypingIndicator: View {
  @State private var dotScale: CGFloat = 1.0
  @State private var dotOpacity: Double = 1.0

  var body: some View {
    HStack(spacing: 2) {
      Text("Typing")
        .font(.caption2.weight(.medium))
        .foregroundStyle(Brand.textSecondary.opacity(0.8))

      ForEach(0..<3) { index in
        Circle()
          .frame(width: 4, height: 4)
          .scaleEffect(dotScale)
          .opacity(dotOpacity)
      }
    }
    .padding(.vertical, 2)
    .padding(.horizontal, 8)
    .background {
      Capsule()
        .fill(Brand.accent.opacity(0.1))
        .overlay {
          Capsule()
            .stroke(Brand.accent.opacity(0.3), lineWidth: 0.5)
        }
    }
    .clipShape(Capsule())
    .onAppear {
      Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        Task { @MainActor in
          withAnimation(AnimationUtilities.responsive) {
            dotScale = dotScale == 1.0 ? 1.3 : 1.0
            dotOpacity = dotOpacity == 1.0 ? 0.6 : 1.0
          }
        }
      }
    }
    .accessibilityLabel("User is typing")
  }
}
