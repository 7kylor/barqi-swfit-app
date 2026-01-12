import SwiftUI

/// Polished, reusable model card component with liquid glass, animations, and enhanced features
struct ModelCard: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let model: AIModel
  let isActive: Bool
  let isRecommended: Bool
  let onSelect: () -> Void
  let onDownload: () -> Void
  let onRetry: () -> Void
  let onRemove: () -> Void

  private var deviceRAM: Int {
    DeviceRAMDetector.getDeviceRAMGB()
  }

  private var isCompatible: Bool {
    guard let requiredRAM = model.requiredRAMGB else { return true }
    return deviceRAM >= requiredRAM
  }

  private var canDownload: Bool {
    model.canDownload && isCompatible
  }

  private var hasEnoughStorage: Bool {
    model.hasEnoughStorage
  }

  private var combinedScore: Int {
    let quality = model.qualityScore > 0 ? model.qualityScore : 0
    let speed = model.speedScore > 0 ? model.speedScore : 0
    if quality == 0 && speed == 0 { return 0 }
    return (quality + speed) / 2
  }

  var body: some View {
    HStack(spacing: Space.md) {
      // Status indicator - hide for available and downloading models
      if model.status != .notDownloaded && model.status != .downloading {
        ModelStateIndicator(
          state: ModelStateVisual.from(
            status: model.status,
            canDownload: canDownload,
            hasStorage: hasEnoughStorage,
            progress: model.progress
          ),
          size: 20,
          reduceMotion: reduceMotion
        )
      }

      // Model info - compact
      VStack(alignment: .leading, spacing: 2) {
        Text(model.friendlyName)
          .font(TypeScale.body)
          .fontWeight(isActive ? .semibold : .medium)
          .foregroundStyle(isActive ? Brand.primary : Brand.textPrimary)
          .lineLimit(1)

        // Compact metadata row
        HStack(spacing: Space.xs) {
          // Combined score metric - simple like RAM and size
          if combinedScore > 0 {
            HStack(spacing: 3) {
              Image(systemName: "star.fill")
                .font(.system(size: 8))
              Text("\(combinedScore)")
                .font(TypeScale.caption2)
            }
            .foregroundStyle(Brand.textSecondary)

            Text("•")
              .foregroundStyle(Brand.textSecondary.opacity(0.5))
              .font(TypeScale.caption2)
          }

          HStack(spacing: 3) {
            Text(L("size"))
              .font(TypeScale.caption2)
              .foregroundStyle(Brand.textSecondary.opacity(0.7))
            Text(model.displaySize)
              .font(TypeScale.caption2)
              .foregroundStyle(Brand.textSecondary)
          }

          if let ram = model.requiredRAMGB {
            Text("•")
              .foregroundStyle(Brand.textSecondary.opacity(0.5))
              .font(TypeScale.caption2)

            HStack(spacing: 3) {
              Image(
                systemName: isCompatible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
              )
              .font(.system(size: 8))
              Text(L("ram"))
                .font(TypeScale.caption2)
                .foregroundStyle(Brand.textSecondary.opacity(0.7))
              Text("\(ram)GB")
                .font(TypeScale.caption2)
            }
            .foregroundStyle(isCompatible ? Brand.textSecondary : Brand.warning)
          }
        }
      }

      Spacer()

      // Action button
      actionButton
    }
    .padding(.vertical, Space.sm)
    .padding(.horizontal, Space.md)
    .contentShape(Rectangle())
    .onTapGesture {
      HapticFeedback.selection()
      handleAction()
    }
    .contextMenu {
      contextMenuContent
    }
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(isActive ? .isSelected : [])
  }

  private var effectiveReduceMotion: Bool {
    reduceMotion
  }

  // MARK: - Action Button

  @ViewBuilder
  private var actionButton: some View {
    Group {
      if isActive {
        Text(L("active"))
          .font(TypeScale.caption)
          .fontWeight(.semibold)
          .foregroundStyle(Brand.primary)
          .padding(.horizontal, Space.md)
          .padding(.vertical, Space.xs)
          .background(
            Capsule()
              .fill(Brand.primary.opacity(0.15))
          )
      } else if model.status == .downloading {
        // Circular progress indicator with percentage
        ZStack {
          Circle()
            .stroke(Brand.primary.opacity(0.2), lineWidth: 2.5)
            .frame(width: 28, height: 28)

          Circle()
            .trim(from: 0, to: model.progress)
            .stroke(
              Brand.primary,
              style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 28, height: 28)
            .animation(.snappy(duration: 0.2), value: model.progress)

          Text("\(Int(model.progress * 100))")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Brand.primary)
            .monospacedDigit()
        }
      } else if model.status == .downloaded {
        // Use button for downloaded models
        Text(L("use"))
          .font(TypeScale.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .padding(.horizontal, Space.md)
          .padding(.vertical, Space.xs)
          .background(
            Capsule()
              .fill(Brand.primary)
          )
      } else if canDownload && hasEnoughStorage {
        // Circular download icon for available models (unified for all formats)
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 22))
          .foregroundStyle(Brand.primary)
      } else {
        Image(systemName: isCompatible ? "info.circle" : "exclamationmark.triangle")
          .font(.system(size: 16))
          .foregroundStyle(isCompatible ? Brand.textSecondary : Brand.warning)
      }
    }
  }

  // MARK: - Context Menu

  @ViewBuilder
  private var contextMenuContent: some View {
    switch model.status {
    case .loaded:
      Button {
        Task { await onUnload() }
      } label: {
        Label(L("unload"), systemImage: "stop.circle")
      }
      if model.provider != .appleFoundation {
        Button(role: .destructive) {
          onRemove()
        } label: {
          Label(L("remove"), systemImage: "trash")
        }
      }

    case .downloaded:
      Button {
        Task { onSelect() }
      } label: {
        Label(L("load"), systemImage: "play.circle")
      }
      if model.provider != .appleFoundation {
        Button(role: .destructive) {
          onRemove()
        } label: {
          Label(L("remove"), systemImage: "trash")
        }
      }

    case .downloading:
      if model.provider != .appleFoundation {
        Button(role: .destructive) {
          onRemove()
        } label: {
          Label(L("cancel"), systemImage: "xmark.circle")
        }
      }

    case .notDownloaded:
      if canDownload && hasEnoughStorage {
        Button {
          onDownload()
        } label: {
          Label(L("download"), systemImage: "arrow.down.circle")
        }
      }

    case .interrupted, .failed:
      Button {
        onRetry()
      } label: {
        Label(L("retry"), systemImage: "arrow.clockwise")
      }
      if model.provider != .appleFoundation {
        Button(role: .destructive) {
          onRemove()
        } label: {
          Label(L("remove"), systemImage: "trash")
        }
      }
    }
  }

  // MARK: - Actions

  private func handleAction() {
    switch model.status {
    case .loaded:
      Task { await onUnload() }
    case .downloaded:
      Task { onSelect() }
    case .notDownloaded:
      if canDownload && hasEnoughStorage {
        onDownload()
      }
    case .interrupted, .failed:
      onRetry()
    case .downloading:
      break  // No action while downloading
    }
  }

  // MARK: - Accessibility

  private var accessibilityLabel: String {
    var label = model.friendlyName
    if isRecommended {
      label += ", \(L("recommended"))"
    }
    if !isCompatible, let ram = model.requiredRAMGB {
      label += ", \(L("device_incompatible", ram))"
    }
    return label
  }

  private var accessibilityHint: String {
    switch model.status {
    case .loaded:
      return L("tap_to_unload")
    case .downloaded:
      return L("tap_to_load")
    case .downloading:
      return L("model_downloading")
    case .notDownloaded:
      return canDownload ? L("tap_to_download") : ""
    case .interrupted, .failed:
      return L("tap_to_retry")
    }
  }

  private func onUnload() async {
    // This would be handled by the parent view
    onSelect()
  }
}

// MARK: - Recommended Ribbon

// MARK: - Preview

#Preview("Model Card") {
  VStack(spacing: Space.md) {
    ModelCard(
      model: AIModel(
        name: "Qwen2.5-7B-Instruct Q4_K_M",
        sizeBytes: 4_700_000_000,
        downloadURL: nil,
        status: .downloaded,
        qualityScore: 88,
        speedScore: 75
      ),
      isActive: false,
      isRecommended: true,
      onSelect: {},
      onDownload: {},
      onRetry: {},
      onRemove: {}
    )

    ModelCard(
      model: AIModel(
        name: "Qwen2.5-3B-Instruct Q4_K_M",
        sizeBytes: 2_000_000_000,
        downloadURL: nil,
        status: .loaded,
        qualityScore: 82,
        speedScore: 85
      ),
      isActive: true,
      isRecommended: false,
      onSelect: {},
      onDownload: {},
      onRetry: {},
      onRemove: {}
    )
  }
  .padding()
  // Note: Preview would need full AppModel setup in real usage
}
