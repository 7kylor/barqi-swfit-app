import SwiftUI

/// Unified visual representation of model states
enum ModelStateVisual: Equatable {
  case notDownloaded(canDownload: Bool, hasStorage: Bool)
  case downloading(progress: Double)
  case downloaded
  case loaded
  case interrupted
  case failed
  case unavailable(reason: String?)
  
  /// Create from AIModel status
  static func from(
    status: ModelStatus,
    canDownload: Bool = true,
    hasStorage: Bool = true,
    progress: Double = 0.0,
    unavailableReason: String? = nil
  ) -> ModelStateVisual {
    switch status {
    case .notDownloaded:
      return .notDownloaded(canDownload: canDownload, hasStorage: hasStorage)
    case .downloading:
      return .downloading(progress: progress)
    case .downloaded:
      return .downloaded
    case .loaded:
      return .loaded
    case .interrupted:
      return .interrupted
    case .failed:
      return .failed
    }
  }
}

/// Unified state indicator component for consistent model state representation
struct ModelStateIndicator: View {
  let state: ModelStateVisual
  let size: CGFloat
  let reduceMotion: Bool
  
  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  
  init(
    state: ModelStateVisual,
    size: CGFloat = 20,
    reduceMotion: Bool = false
  ) {
    self.state = state
    self.size = size
    self.reduceMotion = reduceMotion || false
  }
  
  private var effectiveReduceMotion: Bool {
    reduceMotion || accessibilityReduceMotion
  }
  
  var body: some View {
    Group {
      switch state {
      case .loaded:
        loadedIndicator
      case .downloaded:
        downloadedIndicator
      case .downloading(let progress):
        downloadingIndicator(progress: progress)
      case .notDownloaded(let canDownload, let hasStorage):
        notDownloadedIndicator(canDownload: canDownload, hasStorage: hasStorage)
      case .interrupted:
        interruptedIndicator
      case .failed:
        failedIndicator
      case .unavailable:
        unavailableIndicator
      }
    }
    .frame(width: size, height: size)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
  }
  
  // MARK: - Indicators
  
  @ViewBuilder
  private var loadedIndicator: some View {
    Image(systemName: "checkmark.circle.fill")
      .font(.system(size: size))
      .foregroundStyle(Brand.primary)
      .transition(
        .asymmetric(
          insertion: effectiveReduceMotion 
            ? .opacity 
            : .scale.combined(with: .opacity).animation(.spring(response: 0.2, dampingFraction: 0.7)),
          removal: effectiveReduceMotion 
            ? .opacity 
            : .opacity.animation(.snappy(duration: 0.2))
        )
      )
  }
  
  @ViewBuilder
  private var downloadedIndicator: some View {
    // Empty - no indicator for downloaded state (user taps to load)
    EmptyView()
  }
  
  @ViewBuilder
  private func downloadingIndicator(progress: Double) -> some View {
    ZStack {
      Circle()
        .stroke(Brand.textSecondary.opacity(0.2), lineWidth: 2.5)
        .frame(width: size, height: size)
      
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          Brand.primary,
          style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .frame(width: size, height: size)
        .animation(
          effectiveReduceMotion 
            ? .linear(duration: 0.1) 
            : .snappy(duration: 0.2),
          value: progress
        )
      
      Text("\(Int(progress * 100))")
        .font(.system(size: size * 0.5, weight: .semibold))
        .foregroundStyle(Brand.primary)
        .monospacedDigit()
        .animation(
          effectiveReduceMotion 
            ? .linear(duration: 0.1) 
            : .snappy(duration: 0.15),
          value: progress
        )
    }
  }
  
  @ViewBuilder
  private func notDownloadedIndicator(canDownload: Bool, hasStorage: Bool) -> some View {
    if !canDownload {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: size))
        .foregroundStyle(Brand.textSecondary)
    } else if !hasStorage {
      Image(systemName: "externaldrive.badge.exclamationmark")
        .font(.system(size: size))
        .foregroundStyle(Brand.warning)
    } else {
      Image(systemName: "arrow.down.circle.fill")
        .font(.system(size: size))
        .foregroundStyle(Brand.primary)
    }
  }
  
  @ViewBuilder
  private var interruptedIndicator: some View {
    Image(systemName: "arrow.clockwise.circle.fill")
      .font(.system(size: size))
      .foregroundStyle(Brand.warning)
      .symbolEffect(.pulse, options: .repeating.speed(0.3))
  }
  
  @ViewBuilder
  private var failedIndicator: some View {
    Image(systemName: "exclamationmark.circle.fill")
      .font(.system(size: size))
      .foregroundStyle(Brand.error)
  }
  
  @ViewBuilder
  private var unavailableIndicator: some View {
    Image(systemName: "xmark.circle.fill")
      .font(.system(size: size))
      .foregroundStyle(Brand.textSecondary.opacity(0.5))
  }
  
  // MARK: - Accessibility
  
  private var accessibilityLabel: String {
    switch state {
    case .loaded:
      return L("active")
    case .downloaded:
      return L("downloaded")
    case .downloading(let progress):
      return "\(L("downloading")) \(Int(progress * 100))%"
    case .notDownloaded(let canDownload, let hasStorage):
      if !canDownload {
        return L("unavailable")
      } else if !hasStorage {
        return L("insufficient_storage")
      } else {
        return L("not_downloaded")
      }
    case .interrupted:
      return L("download_interrupted")
    case .failed:
      return L("download_failed")
    case .unavailable:
      return L("unavailable")
    }
  }
  
  private var accessibilityHint: String {
    switch state {
    case .loaded:
      return L("tap_to_unload")
    case .downloaded:
      return L("tap_to_load")
    case .downloading:
      return L("model_downloading")
    case .notDownloaded(let canDownload, _):
      return canDownload ? L("tap_to_download") : ""
    case .interrupted, .failed:
      return L("tap_to_retry")
    case .unavailable:
      return ""
    }
  }
}

// MARK: - Preview

#Preview("Model States") {
  VStack(spacing: Space.lg) {
    ModelStateIndicator(state: .loaded)
    ModelStateIndicator(state: .downloaded)
    ModelStateIndicator(state: .downloading(progress: 0.65))
    ModelStateIndicator(state: .notDownloaded(canDownload: true, hasStorage: true))
    ModelStateIndicator(state: .notDownloaded(canDownload: false, hasStorage: true))
    ModelStateIndicator(state: .notDownloaded(canDownload: true, hasStorage: false))
    ModelStateIndicator(state: .interrupted)
    ModelStateIndicator(state: .failed)
    ModelStateIndicator(state: .unavailable(reason: "Incompatible"))
  }
  .padding()
}
