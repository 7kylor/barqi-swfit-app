import SwiftUI

/// Floating pill showing download progress at top of screen
/// Supports multiple parallel downloads with aggregated progress
/// Dismissible - continues download in background when swiped away
struct DownloadProgressPill: View {
  let state: DownloadNotificationState
  let downloadCount: Int
  let aggregatedProgress: Double
  let onDismiss: () -> Void
  let onTap: () -> Void

  @State private var offset: CGFloat = 0
  @State private var isDragging = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let dismissThreshold: CGFloat = -80

  init(
    state: DownloadNotificationState,
    downloadCount: Int,
    aggregatedProgress: Double,
    onDismiss: @escaping () -> Void,
    onTap: @escaping () -> Void
  ) {
    self.state = state
    self.downloadCount = downloadCount
    self.aggregatedProgress = aggregatedProgress
    self.onDismiss = onDismiss
    self.onTap = onTap
  }

  var body: some View {
    HStack(spacing: Space.md) {
      // Progress circle with count badge
      ZStack(alignment: .topTrailing) {
        progressIndicator

        // Download count badge (only show for 2+ downloads)
        if downloadCount > 1 {
          Text("\(downloadCount)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Brand.primary)
            .clipShape(Circle())
            .offset(x: 6, y: -6)
        }
      }

      // Content
      VStack(alignment: .leading, spacing: 2) {
        if downloadCount > 1 {
          Text(L("downloading_count_models", downloadCount))
            .font(TypeScale.subhead)
            .fontWeight(.medium)
            .foregroundStyle(Brand.textPrimary)
            .lineLimit(1)
        } else {
          Text(state.modelName)
            .font(TypeScale.subhead)
            .fontWeight(.medium)
            .foregroundStyle(Brand.textPrimary)
            .lineLimit(1)
        }

        HStack(spacing: Space.xs) {
          Text(downloadCount > 1 ? "\(Int(aggregatedProgress * 100))%" : state.statusText)
            .font(TypeScale.caption)
            .foregroundStyle(Brand.textSecondary)

          if state.speed > 0 && state.isDownloading && downloadCount == 1 {
            Text(state.formattedSpeed)
              .font(TypeScale.caption)
              .foregroundStyle(Brand.textSecondary.opacity(0.7))
          }
        }
      }

      Spacer()

      // Close button (visible when not dragging)
      if !isDragging {
        Button {
          HapticFeedback.impact(style: .light)
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Brand.textSecondary)
            .frame(width: 28, height: 28)
            .background(
              Circle()
                .fill(Brand.textSecondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("dismiss"))
      }
    }
    .padding(.horizontal, Space.lg)
    .padding(.vertical, Space.md)
    .frame(maxWidth: 360)
    .liquidGlass(cornerRadius: Radius.xxl)
    .overlay {
      RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
        .stroke(Brand.textSecondary.opacity(0.1), lineWidth: 0.5)
    }
    .offset(y: offset)
    .gesture(dragGesture)
    .onTapGesture {
      HapticFeedback.selection()
      onTap()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      downloadCount > 1
        ? L("downloads_in_progress", downloadCount, Int(aggregatedProgress * 100))
        : L(
          "download_progress_accessibility", state.modelName, state.statusText,
          state.progressPercentage)
    )
    .accessibilityHint(L("tap_for_details_swipe_dismiss"))
  }

  // MARK: - Progress Indicator

  @ViewBuilder
  private var progressIndicator: some View {
    ZStack {
      Circle()
        .stroke(Brand.primary.opacity(0.15), lineWidth: 3)
        .frame(width: 36, height: 36)

      Circle()
        .trim(from: 0, to: aggregatedProgress)
        .stroke(
          Brand.primary,
          style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .frame(width: 36, height: 36)
        .animation(
          reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.7),
          value: aggregatedProgress
        )

      if state.isDownloading {
        Text("\(Int(aggregatedProgress * 100))")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(Brand.primary)
          .monospacedDigit()
      } else if state.error != nil {
        Image(systemName: "exclamationmark")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Brand.error)
      } else {
        Image(systemName: "checkmark")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Brand.success)
      }
    }
  }

  // MARK: - Drag Gesture

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 10)
      .onChanged { value in
        isDragging = true
        let translation = min(0, value.translation.height)
        offset = translation
      }
      .onEnded { value in
        isDragging = false

        if value.translation.height < dismissThreshold {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = -200
          }
          HapticFeedback.impact(style: .light)

          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
          }
        } else {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
          }
        }
      }
  }
}

// MARK: - Download Sheet (Unified for Single and Multiple)

struct DownloadSheet: View {
  let downloads: [DownloadNotificationState]
  let aggregatedState: AggregatedDownloadState
  let onDismiss: () -> Void
  let onCancel: (UUID) -> Void
  let onCancelAll: () -> Void

  private var hasActiveDownloads: Bool {
    downloads.contains { $0.isDownloading }
  }

  private var totalProgress: Double {
    if downloads.count == 1 {
      return downloads.first?.progress ?? 0
    }
    return aggregatedState.overallProgress
  }

  private var hasError: Bool {
    downloads.contains { $0.error != nil }
  }

  private var isComplete: Bool {
    !downloads.isEmpty && downloads.allSatisfy { !$0.isDownloading && $0.error == nil }
  }

  var body: some View {
    NavigationStack {
      Group {
        if downloads.isEmpty {
          // Empty state - auto dismiss
          Color.clear
            .onAppear {
              onDismiss()
            }
        } else {
          VStack(spacing: 0) {
            // Big progress circle
            progressCircle
              .padding(.top, Space.xl)
              .padding(.bottom, Space.lg)

            if downloads.count > 1 {
              // Download list for multiple items
              downloadList
            } else if let download = downloads.first {
              // Single download stats detail
              singleDownloadStats(download)
                .padding(.horizontal, Space.lg)
            }

            Spacer()
          }
        }
      }
      .background(Brand.surface)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            if hasActiveDownloads {
              Button {
                HapticFeedback.notification(.warning)
                onCancelAll()
              } label: {
                Text(L("cancel"))
                  .foregroundStyle(Brand.error)
              }
            }
          }

          ToolbarItem(placement: .topBarTrailing) {
            Button(L("done")) {
              HapticFeedback.selection()
              onDismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(Brand.primary)
          }
        #else
          ToolbarItem(placement: .cancellationAction) {
            if hasActiveDownloads {
              Button {
                onCancelAll()
              } label: {
                Text(L("cancel"))
                  .foregroundStyle(Brand.error)
              }
            }
          }

          ToolbarItem(placement: .confirmationAction) {
            Button(L("done")) {
              onDismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(Brand.primary)
          }
        #endif
      }
    }
    .presentationDetents(downloads.count > 1 ? [.medium, .large] : [.medium])
    .presentationDragIndicator(downloads.count > 1 ? .visible : .hidden)
    .onChange(of: downloads.count) { _, count in
      // Auto-dismiss when no more downloads
      if count == 0 {
        onDismiss()
      }
    }
  }

  // MARK: - Progress Circle

  @ViewBuilder
  private var progressCircle: some View {
    VStack(spacing: Space.md) {
      ZStack {
        // Background ring
        Circle()
          .stroke(Brand.primary.opacity(0.15), lineWidth: 10)
          .frame(width: 140, height: 140)

        // Progress ring
        Circle()
          .trim(from: 0, to: totalProgress)
          .stroke(
            progressColor,
            style: StrokeStyle(lineWidth: 10, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 140, height: 140)
          .animation(.linear(duration: 0.2), value: totalProgress)

        // Center content
        VStack(spacing: 4) {
          if hasError {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 32))
              .foregroundStyle(Brand.error)
          } else if isComplete {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 32))
              .foregroundStyle(Brand.success)
          } else {
            Text("\(Int(totalProgress * 100))%")
              .font(.system(size: 36, weight: .bold, design: .rounded))
              .foregroundStyle(Brand.textPrimary)
              .monospacedDigit()
          }
        }
      }

      // Status text
      if downloads.count == 1, let download = downloads.first {
        Text(download.modelName)
          .font(TypeScale.headline)
          .foregroundStyle(Brand.textPrimary)
          .lineLimit(1)

        Text(download.statusText)
          .font(TypeScale.subhead)
          .foregroundStyle(Brand.textSecondary)
      } else if downloads.count > 1 {
        Text(L("downloading_count_models", downloads.count))
          .font(TypeScale.headline)
          .foregroundStyle(Brand.textPrimary)

        Text(aggregatedState.formattedProgress)
          .font(TypeScale.subhead)
          .foregroundStyle(Brand.textSecondary)
      }
    }
  }

  private var progressColor: Color {
    if hasError {
      return Brand.error
    } else if isComplete {
      return Brand.success
    }
    return Brand.primary
  }

  // MARK: - Download List

  @ViewBuilder
  private var downloadList: some View {
    ScrollView {
      LazyVStack(spacing: Space.md) {
        ForEach(downloads) { download in
          downloadRow(download)
        }
      }
      .padding(.vertical, Space.md)
    }
  }

  @ViewBuilder
  private func singleDownloadStats(_ download: DownloadNotificationState) -> some View {
    VStack(spacing: Space.lg) {
      if download.isDownloading {
        statsCard(download)
      } else if let error = download.error {
        errorCard(error)
      }
    }
  }

  @ViewBuilder
  private func statsCard(_ download: DownloadNotificationState) -> some View {
    HStack(spacing: 0) {
      statItem(
        value: download.speed > 0 ? download.formattedSpeed : L("calculating"),
        label: L("speed")
      )

      Divider()
        .frame(height: 30)

      statItem(value: download.formattedProgress, label: L("downloaded"))
    }
    .padding(.vertical, Space.lg)
    .background(
      RoundedRectangle(cornerRadius: Radius.xl)
        .fill(Brand.surface)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .overlay(
          RoundedRectangle(cornerRadius: Radius.xl)
            .stroke(Brand.textSecondary.opacity(0.1), lineWidth: 1)
        )
    )
  }

  @ViewBuilder
  private func statItem(value: String, label: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(TypeScale.headline)
        .fontWeight(.semibold)
        .foregroundStyle(Brand.textPrimary)

      Text(label)
        .font(TypeScale.caption)
        .foregroundStyle(Brand.textSecondary)
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func errorCard(_ error: String) -> some View {
    Text(error)
      .font(TypeScale.body)
      .foregroundStyle(Brand.error)
      .multilineTextAlignment(.center)
      .padding()
      .background(
        RoundedRectangle(cornerRadius: Radius.lg)
          .fill(Brand.error.opacity(0.1))
      )
  }

  @ViewBuilder
  private func downloadRow(_ download: DownloadNotificationState) -> some View {
    HStack(spacing: Space.md) {
      // Circular progress indicator
      ZStack {
        Circle()
          .stroke(Brand.primary.opacity(0.15), lineWidth: 4)
          .frame(width: 44, height: 44)

        if download.isDownloading {
          Circle()
            .trim(from: 0, to: download.progress)
            .stroke(
              Brand.primary,
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 44, height: 44)
            .animation(.linear(duration: 0.2), value: download.progress)

          Text("\(download.progressPercentage)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Brand.primary)
            .monospacedDigit()
        } else if download.error != nil {
          Image(systemName: "exclamationmark")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Brand.error)
        } else {
          Image(systemName: "checkmark")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Brand.success)
        }
      }

      // Content
      VStack(alignment: .leading, spacing: 4) {
        Text(download.modelName)
          .font(TypeScale.subhead)
          .fontWeight(.medium)
          .foregroundStyle(Brand.textPrimary)
          .lineLimit(1)

        if download.isDownloading {
          HStack(spacing: Space.xs) {
            if download.speed > 0 {
              Text(download.formattedSpeed)
                .font(TypeScale.caption)
                .foregroundStyle(Brand.textSecondary)

              Text("•")
                .font(TypeScale.caption)
                .foregroundStyle(Brand.textSecondary.opacity(0.5))
            }

            Text(download.formattedProgress)
              .font(TypeScale.caption)
              .foregroundStyle(Brand.textSecondary)
          }
        } else if let error = download.error {
          Text(error)
            .font(TypeScale.caption)
            .foregroundStyle(Brand.error)
            .lineLimit(1)
        } else {
          Text(L("download_complete"))
            .font(TypeScale.caption)
            .foregroundStyle(Brand.success)
        }
      }

      Spacer()

      // Cancel button (only when downloading)
      if download.isDownloading {
        Button {
          HapticFeedback.notification(.warning)
          if let modelId = download.modelId {
            onCancel(modelId)
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(Brand.textSecondary.opacity(0.4))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, Space.lg)
    .padding(.vertical, Space.md)
    .background(
      RoundedRectangle(cornerRadius: Radius.lg)
        .fill(Brand.surface)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .overlay(
          RoundedRectangle(cornerRadius: Radius.lg)
            .stroke(Brand.textSecondary.opacity(0.1), lineWidth: 0.5)
        )
    )
    .padding(.horizontal, Space.lg)
  }
}

// MARK: - Preview

#Preview("Download Pill - Single") {
  VStack {
    Spacer()

    DownloadProgressPill(
      state: DownloadNotificationState(
        modelId: UUID(),
        modelName: "Qwen2.5-7B-Instruct Q4_K_M",
        progress: 0.65,
        statusText: "Downloading: 65%",
        isDownloading: true,
        isPillVisible: true,
        isBannerVisible: false,
        error: nil,
        speed: 5_500_000,
        bytesDownloaded: 3_000_000_000,
        totalBytes: 4_700_000_000
      ),
      downloadCount: 1,
      aggregatedProgress: 0.65,
      onDismiss: {},
      onTap: {}
    )
    .padding()

    Spacer()
  }
  .background(Brand.surface)
}

#Preview("Download Sheet - Single") {
  DownloadSheet(
    downloads: [
      DownloadNotificationState(
        modelId: UUID(),
        modelName: "Qwen2.5-7B-Instruct Q4_K_M",
        progress: 0.65,
        statusText: "Downloading: 65%",
        isDownloading: true,
        isPillVisible: true,
        isBannerVisible: false,
        error: nil,
        speed: 5_500_000,
        bytesDownloaded: 3_000_000_000,
        totalBytes: 4_700_000_000
      )
    ],
    aggregatedState: .idle,
    onDismiss: {},
    onCancel: { _ in },
    onCancelAll: {}
  )
}

#Preview("Download Sheet - Multiple") {
  DownloadSheet(
    downloads: [
      DownloadNotificationState(
        modelId: UUID(),
        modelName: "Qwen2.5-7B-Instruct",
        progress: 0.80,
        statusText: "80%",
        isDownloading: true,
        isPillVisible: true,
        isBannerVisible: false,
        error: nil,
        speed: 5_500_000,
        bytesDownloaded: 3_000_000_000,
        totalBytes: 4_700_000_000
      ),
      DownloadNotificationState(
        modelId: UUID(),
        modelName: "Llama-3.2-3B-Instruct",
        progress: 0.45,
        statusText: "45%",
        isDownloading: true,
        isPillVisible: true,
        isBannerVisible: false,
        error: nil,
        speed: 3_200_000,
        bytesDownloaded: 1_000_000_000,
        totalBytes: 2_200_000_000
      ),
    ],
    aggregatedState: AggregatedDownloadState(
      totalDownloads: 2,
      completedDownloads: 0,
      overallProgress: 0.625,
      totalBytesDownloaded: 4_000_000_000,
      totalBytesExpected: 6_900_000_000,
      isAnyDownloading: true,
      primaryModelName: "Qwen2.5-7B-Instruct"
    ),
    onDismiss: {},
    onCancel: { _ in },
    onCancelAll: {}
  )
}
