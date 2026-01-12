import SwiftUI

struct ModelCard: View {
  let model: AIModel
  let isActive: Bool
  let onSelect: () -> Void

  var body: some View {
    HStack(spacing: Space.md) {
      VStack(alignment: .leading, spacing: 2) {
        Text(model.name)
          .font(TypeScale.body)
          .fontWeight(isActive ? .semibold : .medium)
          .foregroundStyle(isActive ? Brand.primary : Brand.textPrimary)

        Text(model.providerRaw.capitalized)
          .font(TypeScale.caption2)
          .foregroundStyle(Brand.textSecondary)
      }

      Spacer()

      if isActive {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Brand.primary)
      }
    }
    .padding(.vertical, Space.sm)
    .padding(.horizontal, Space.md)
    .contentShape(Rectangle())
    .onTapGesture {
      onSelect()
    }
  }
}
