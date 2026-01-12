import SwiftUI

/// Progress circle view for download progress
fileprivate struct ProgressCircleView: View {
  let progressPercentage: Int
  let reduceMotion: Bool

  var body: some View {
    ZStack {
      Circle()
        .stroke(Brand.textSecondary.opacity(0.2), lineWidth: 2.5)
        .frame(width: 20, height: 20)

      Circle()
        .trim(from: 0, to: Double(progressPercentage) / 100.0)
        .stroke(Brand.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .frame(width: 20, height: 20)
        .animation(reduceMotion ? .linear(duration: 0.1) : .snappy(duration: 0.2), value: progressPercentage)

      Text("\(progressPercentage)")
        .font(TypeScale.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(Brand.primary)
        .monospacedDigit()
        .animation(reduceMotion ? .linear(duration: 0.1) : .snappy(duration: 0.15), value: progressPercentage)
    }
    .frame(width: 20, height: 20)
  }
}

/// Simplified model row matching the ConversationsList row style
struct ModelRow: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let model: AIModel
  let isLoaded: Bool
  let displaySize: String
  let ramRequirement: Int?
  let canDownload: Bool
  let hasEnoughStorage: Bool
  let storageWarning: String?
  let unsupportedReason: String?
  let progressPercentage: Int
  let onLoad: () async -> Void
  let onUnload: () async -> Void
  let onDownload: () -> Void
  let onRetry: () -> Void
  let onRemove: () -> Void

  /// Track if this model is currently being loaded
  @State private var isLoadingModel = false

  private var isRTL: Bool {
    RTLUtilities.isRTL
  }

  private var layoutDirection: LayoutDirection {
    RTLUtilities.layoutDirection
  }

  /// The visual state indicator to show next to the model name (only for loading state)
  /// Standardized icon size: 20x20pt for consistency with other status icons
  @ViewBuilder
  private var modelStateIndicator: some View {
    if isLoadingModel {
      // Loading spinner with brand color - shown next to name during loading
      ProgressView()
        .progressViewStyle(.circular)
        .tint(Brand.primary)
        .frame(width: 20, height: 20)
        .transition(
          .asymmetric(
            insertion: reduceMotion ? .opacity : .scale.combined(with: .opacity).animation(.spring(response: 0.2, dampingFraction: 0.7)),
            removal: reduceMotion ? .opacity : .opacity.animation(.snappy(duration: 0.2))
          ))
    }
  }

  var body: some View {
    Button {
      handleTap()
    } label: {
      HStack(alignment: .center, spacing: Space.md) {
        // RTL-aware content ordering
        if isRTL {
          // In RTL: status action first, then content
          statusAction
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .center, spacing: Space.sm) {
              if isLoadingModel {
                modelStateIndicator
                  .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.8), value: isLoadingModel)
              }

              Text(model.name)
                .font(TypeScale.body)
                .fontWeight(isLoaded || isLoadingModel ? .semibold : .medium)
                .foregroundStyle(isLoaded || isLoadingModel ? Brand.primary : Brand.textPrimary)
                .lineLimit(1)
            }

            HStack(spacing: Space.xs) {
              if let ramRequired = ramRequirement {
                Text(L("ram_requirement", ramRequired))
                  .font(TypeScale.caption)
                  .foregroundStyle(canDownload ? Brand.textSecondary : Brand.warning)
                Text("•")
                  .font(TypeScale.caption)
                  .foregroundStyle(Brand.textSecondary.opacity(0.5))
              }
              
              modelStats

              Text(displaySize)
                .font(TypeScale.caption)
                .foregroundStyle(Brand.textSecondary)
            }
          }
        } else {
          // In LTR: content first, then status action
          VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: Space.sm) {
              if isLoadingModel {
                modelStateIndicator
                  .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.8), value: isLoadingModel)
              }

              Text(model.name)
                .font(TypeScale.body)
                .fontWeight(isLoaded || isLoadingModel ? .semibold : .medium)
                .foregroundStyle(isLoaded || isLoadingModel ? Brand.primary : Brand.textPrimary)
                .lineLimit(1)
            }

            HStack(spacing: Space.xs) {
              Text(displaySize)
                .font(TypeScale.caption)
                .foregroundStyle(Brand.textSecondary)

              modelStats

              if let ramRequired = ramRequirement {
                Text("•")
                  .font(TypeScale.caption)
                  .foregroundStyle(Brand.textSecondary.opacity(0.5))
                Text(L("ram_requirement", ramRequired))
                  .font(TypeScale.caption)
                  .foregroundStyle(canDownload ? Brand.textSecondary : Brand.warning)
              }
            }
          }

          Spacer()

          // Trailing side: action button
          statusAction
        }
      }
      .padding(.vertical, Space.sm)
      .padding(.horizontal, Space.md)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!canInteract || isLoadingModel)
    .environment(\.layoutDirection, layoutDirection)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      swipeTrailingActions
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      swipeLeadingActions
    }
    .contextMenu {
      contextMenuContent
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityDescription)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(isLoaded ? .isSelected : [])
    .onChange(of: isLoaded) { _, newValue in
      // When model becomes loaded, stop the loading indicator
      if newValue {
        withAnimation(.snappy(duration: 0.3)) {
          isLoadingModel = false
        }
      }
    }
  }

  // MARK: - Status Action

  @ViewBuilder
  private var statusAction: some View {
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

  // MARK: - Swipe Actions

  @ViewBuilder
  private var swipeTrailingActions: some View {
    // Right swipe: Remove/Cancel actions
    if model.status == .downloading {
      Button(role: .destructive) {
        HapticFeedback.impact(style: .medium)
        onRemove()
      } label: {
        Label(L("cancel"), systemImage: "xmark.circle.fill")
      }
      .tint(Brand.error)
    } else if model.status == .downloaded || model.status == .failed || model.status == .interrupted {
      if model.provider != .appleFoundation {
        Button(role: .destructive) {
          HapticFeedback.impact(style: .medium)
          onRemove()
        } label: {
          Label(L("remove"), systemImage: "trash.fill")
        }
        .tint(Brand.error)
      }
    }
  }

  @ViewBuilder
  private var swipeLeadingActions: some View {
    // Left swipe: Download/Use actions
    switch model.status {
    case .notDownloaded:
      if canDownload && hasEnoughStorage {
        Button {
          HapticFeedback.selection()
          onDownload()
        } label: {
          Label(L("download"), systemImage: "arrow.down.circle.fill")
        }
        .tint(Brand.primary)
      }
    case .downloaded:
      Button {
        HapticFeedback.selection()
        Task { await onLoad() }
      } label: {
        Label(L("use"), systemImage: "play.circle.fill")
      }
      .tint(Brand.success)
    case .interrupted, .failed:
      Button {
        HapticFeedback.selection()
        onRetry()
      } label: {
        Label(L("retry"), systemImage: "arrow.clockwise.circle.fill")
      }
      .tint(Brand.warning)
    case .loaded:
      Button {
        HapticFeedback.selection()
        Task { await onUnload() }
      } label: {
        Label(L("unload"), systemImage: "stop.circle.fill")
      }
      .tint(Brand.textSecondary)
    default:
      EmptyView()
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
        Task { await onLoad() }
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
      if canDownload && model.provider != .appleFoundation {
        if hasEnoughStorage {
          Button {
            onDownload()
          } label: {
            Label(L("download"), systemImage: "arrow.down.circle")
          }
        } else if let warning = storageWarning {
          Text(warning)
            .font(TypeScale.caption)
        }
      } else if !canDownload {
        if let reason = unsupportedReason {
          Text(reason)
            .font(TypeScale.caption)
        }
      }

    case .interrupted:
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

    case .failed:
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

  // MARK: - Computed Properties

  private var canInteract: Bool {
    // Disable interaction while loading or downloading
    if isLoadingModel { return false }
    switch model.status {
    case .downloading:
      return false
    default:
      // Always allow interaction - handleTap will provide feedback if download isn't possible
      return true
    }
  }

  private var accessibilityDescription: String {
    let size = displaySize
    let status: String
    switch model.status {
    case .loaded: status = L("loaded")
    case .downloaded: status = L("downloaded")
    case .downloading: status = "\(L("downloading")) \(progressPercentage)%"
    case .notDownloaded: status = canDownload ? L("not_downloaded") : L("unsupported")
    case .interrupted: status = L("interrupted")
    case .failed: status = L("failed")
    }
    return "\(model.name), \(size), \(status)"
  }

  private var accessibilityHint: String {
    switch model.status {
    case .loaded: return L("tap_to_unload")
    case .downloaded: return L("tap_to_load")
    case .notDownloaded: return canDownload ? L("tap_to_download") : ""
    case .interrupted, .failed: return L("tap_to_retry")
    case .downloading: return ""
    }
  }

  @ViewBuilder
  private var modelStats: some View {
      if model.qualityScore > 0 {
          Text("•")
            .font(TypeScale.caption)
            .foregroundStyle(Brand.textSecondary.opacity(0.5))
          HStack(spacing: 2) {
              Image(systemName: "sparkles")
                  .font(TypeScale.caption2)
              Text("\(model.qualityScore)")
                  .font(TypeScale.caption)
          }
          .foregroundStyle(Brand.textSecondary)
      }
      if model.speedScore > 0 {
          Text("•")
            .font(TypeScale.caption)
            .foregroundStyle(Brand.textSecondary.opacity(0.5))
          HStack(spacing: 2) {
              Image(systemName: "bolt")
                  .font(TypeScale.caption2)
              Text("\(model.speedScore)")
                  .font(TypeScale.caption)
          }
          .foregroundStyle(Brand.textSecondary)
      }
  }

  // MARK: - Actions

  private func handleTap() {
    HapticFeedback.selection()
    Logger.log(
      "ModelRow tap: \(model.name), status=\(model.status), canDownload=\(canDownload), hasStorage=\(hasEnoughStorage)",
      category: Logger.model)
    switch model.status {
    case .loaded:
      Task { await onUnload() }
    case .downloaded:
      // Show loading indicator immediately with smooth animation
      withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.8)) {
        isLoadingModel = true
      }
      Task {
        await onLoad()
        // If loading failed, hide the loading indicator
        if !isLoaded {
          await MainActor.run {
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .snappy(duration: 0.2)) {
          isLoadingModel = false
        }
          }
        }
      }
    case .notDownloaded:
      if canDownload && hasEnoughStorage {
        Logger.log("ModelRow: triggering download for \(model.name)", category: Logger.model)
        onDownload()
      } else {
        // Provide feedback for why download isn't possible
        HapticFeedback.notification(.error)
        Logger.log(
          "ModelRow: cannot download \(model.name) - canDownload=\(canDownload), hasStorage=\(hasEnoughStorage)",
          level: .info, category: Logger.model)
      }
    case .interrupted, .failed:
      onRetry()
    case .downloading:
      break
    }
  }
}
