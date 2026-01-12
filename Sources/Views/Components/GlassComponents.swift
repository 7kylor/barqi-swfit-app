import SwiftUI

// MARK: - Glass Card Container
struct GlassCard<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(Space.lg)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
  }
}

// MARK: - Glass Section Header
struct GlassSectionHeader: View {
  let title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(TypeScale.title)
      .fontWeight(.semibold)
      .foregroundStyle(Brand.textPrimary)
      .padding(.horizontal, Space.lg)
      .padding(.top, Space.xl)
      .padding(.bottom, Space.md)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Glass Toggle Row
struct GlassToggleRow: View {
  let title: String
  let systemImage: String?
  @Binding var isOn: Bool
  let action: (() -> Void)?

  init(
    _ title: String,
    systemImage: String? = nil,
    isOn: Binding<Bool>,
    action: (() -> Void)? = nil
  ) {
    self.title = title
    self.systemImage = systemImage
    self._isOn = isOn
    self.action = action
  }

  var body: some View {
    Button {
      HapticFeedback.selection()
      isOn.toggle()
      action?()
    } label: {
      HStack(spacing: Space.md) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(TypeScale.body)
            .foregroundStyle(Brand.primary)
            .frame(width: 24)
        }

        Text(title)
          .font(TypeScale.body)
          .foregroundStyle(Brand.textPrimary)
          .multilineTextAlignment(.leading)

        Spacer()

        Toggle("", isOn: $isOn)
          .labelsHidden()
          .tint(Brand.primary)
      }
      .padding(.vertical, Space.sm)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityValue(isOn ? L("On") : L("Off"))
    .accessibilityHint(L("Double tap to toggle"))
  }
}

// MARK: - Glass Navigation Row
struct GlassNavigationRow<Destination: View>: View {
  let title: String
  let systemImage: String?
  let value: String?
  let destination: Destination

  init(
    _ title: String,
    systemImage: String? = nil,
    value: String? = nil,
    @ViewBuilder destination: () -> Destination
  ) {
    self.title = title
    self.systemImage = systemImage
    self.value = value
    self.destination = destination()
  }

  var body: some View {
    NavigationLink {
      destination
    } label: {
      HStack(spacing: Space.md) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(TypeScale.body)
            .foregroundStyle(Brand.primary)
            .frame(width: 24)
        }

        Text(title)
          .font(TypeScale.body)
          .foregroundStyle(Brand.textPrimary)
          .multilineTextAlignment(.leading)

        Spacer()

        if let value {
          Text(value)
            .font(TypeScale.subhead)
            .foregroundStyle(Brand.textSecondary)
        }

        Image(systemName: "chevron.right")
          .font(TypeScale.caption)
          .foregroundStyle(Brand.textSecondary)
          .imageScale(.small)
          .flipsForRightToLeftLayoutDirection(true)
      }
      .padding(.vertical, Space.sm)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityHint("Double tap to navigate")
  }
}

// MARK: - Glass Action Row
struct GlassActionRow: View {
  let title: String
  let systemImage: String?
  let role: ButtonRole?
  let action: () -> Void

  init(
    _ title: String,
    systemImage: String? = nil,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.role = role
    self.action = action
  }

  var body: some View {
    Button {
      HapticFeedback.selection()
      action()
    } label: {
      HStack(spacing: Space.md) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(TypeScale.body)
            .foregroundStyle(role == .destructive ? Brand.error : Brand.primary)
            .frame(width: 24)
        }

        Text(title)
          .font(TypeScale.body)
          .foregroundStyle(role == .destructive ? Brand.error : Brand.textPrimary)
          .multilineTextAlignment(.leading)

        Spacer()
      }
      .padding(.vertical, Space.sm)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityHint(role == .destructive ? "Double tap to delete" : "Double tap to perform action")
  }
}

// MARK: - Glass Info Row
struct GlassInfoRow: View {
  let title: String
  let value: String
  let systemImage: String?

  init(_ title: String, value: String, systemImage: String? = nil) {
    self.title = title
    self.value = value
    self.systemImage = systemImage
  }

  var body: some View {
    HStack(spacing: Space.md) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(TypeScale.body)
          .foregroundStyle(Brand.primary)
          .frame(width: 24)
      }

      Text(title)
        .font(TypeScale.body)
        .foregroundStyle(Brand.textPrimary)

      Spacer()

      Text(value)
        .font(TypeScale.subhead)
        .foregroundStyle(Brand.textSecondary)
    }
    .padding(.vertical, Space.sm)
  }
}

// MARK: - Glass Button
struct GlassButton: View {
  let title: String
  let systemImage: String?
  let role: ButtonRole?
  let action: () -> Void

  init(
    _ title: String,
    systemImage: String? = nil,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.role = role
    self.action = action
  }

  var body: some View {
    Button {
      HapticFeedback.selection()
      action()
    } label: {
      HStack(spacing: Space.sm) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(TypeScale.body)
        }
        Text(title)
          .font(TypeScale.headline)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Space.md)
      .glassEffect(
        .regular.tint(role == .destructive ? Brand.error.opacity(0.15) : Brand.primary.opacity(0.15)),
        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
      )
      .foregroundStyle(role == .destructive ? Brand.error : Brand.primary)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityHint(role == .destructive ? "Double tap to delete" : "Double tap to perform action")
  }
}
