import SwiftUI

/// Minimal, native expandable disclosure for showing hidden reasoning (Grok-style)
struct ReasoningDisclosure: View {
  let text: String
  @State private var isExpanded: Bool = false
  var layoutDirection: LayoutDirection = RTLUtilities.layoutDirection
  
  private var chevronIcon: String { isExpanded ? "chevron.down" : "chevron.right" }

  var body: some View {
    VStack(alignment: .leading, spacing: Space.xs) {
      Button {
        withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
      } label: {
        HStack(spacing: Space.xs) {
          Image(systemName: chevronIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.textSecondary)
            .accessibilityHidden(true)
            .flipsForRightToLeftLayoutDirection(true)
          Text(isExpanded ? L("hide_thinking") : L("show_thinking"))
            .font(TypeScale.caption)
            .foregroundStyle(Brand.textSecondary)
            .textCase(.uppercase)
            .multilineTextAlignment(.leading)
            .accessibilityLabel(isExpanded ? L("hide_thinking") : L("show_thinking"))
            .accessibilityHint(
              isExpanded ? L("hide_thinking_hint") : L("show_thinking_hint"))
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isExpanded {
        Text(text)
          .font(TypeScale.caption)
          .foregroundStyle(Brand.textSecondary)
          .textSelection(.enabled)
          .multilineTextAlignment(.leading)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 2)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(.top, Space.xs)
    .environment(\.layoutDirection, layoutDirection)
  }
}
