import SwiftData
import SwiftUI

// MARK: - Container View for Download Overlays

/// Container for download overlay UI
/// Shows floating pill for active downloads with support for parallel downloads
/// Pill is positioned below navigation toolbar for non-blocking interaction
struct DownloadOverlayContainer: View {
  @Environment(AppModel.self) private var app
  @Query private var models: [AIModel]
  @State private var notificationService = InAppDownloadNotificationService.shared
  @State private var showDetailSheet = false

  private var shouldShowPill: Bool {
    // Only show if isPillVisible is true and there are active downloads
    notificationService.isPillVisible && notificationService.hasActiveDownloads
  }

  var body: some View {
    ZStack(alignment: .top) {
      // Floating pill below toolbar - dismissible, non-blocking
      if shouldShowPill {
        VStack {
          DownloadProgressPill(
            state: notificationService.state,
            downloadCount: notificationService.downloadCount,
            aggregatedProgress: notificationService.aggregatedState.overallProgress,
            onDismiss: {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                notificationService.dismissPill()
              }
            },
            onTap: {
              // Only show sheet if there are downloads
              if notificationService.hasActiveDownloads {
                showDetailSheet = true
              }
            }
          )
          .transition(
            .asymmetric(
              insertion: .move(edge: .top).combined(with: .opacity),
              removal: .move(edge: .top).combined(with: .opacity)
            )
          )
          // Position below navigation bar (safe area + toolbar height)
          .padding(.top, 56)
          .padding(.horizontal, Space.md)

          Spacer()
        }
      }
    }
    .animation(
      .spring(response: 0.3, dampingFraction: 0.8), value: notificationService.isPillVisible
    )
    .animation(
      .spring(response: 0.3, dampingFraction: 0.8), value: notificationService.hasActiveDownloads
    )
    .onChange(of: notificationService.hasActiveDownloads) { _, hasDownloads in
      // Auto-dismiss sheet when no more downloads
      if !hasDownloads && showDetailSheet {
        showDetailSheet = false
      }
    }
    .sheet(isPresented: $showDetailSheet) {
      // Only present if there are downloads
      if notificationService.hasActiveDownloads {
        DownloadSheet(
          downloads: notificationService.downloadingModels,
          aggregatedState: notificationService.aggregatedState,
          onDismiss: {
            showDetailSheet = false
          },
          onCancel: { modelId in
            cancelDownload(modelId: modelId)
          },
          onCancelAll: {
            cancelAllDownloads()
          }
        )
      }
    }
  }

  // Helper to cancel download by ID
  private func cancelDownload(modelId: UUID) {
    if let model = models.first(where: { $0.id == modelId }) {
      app.downloadService.cancelDownload(model: model)
    } else {
      notificationService.cancelDownload(modelId: modelId)
    }
  }

  // Helper to cancel all downloads
  private func cancelAllDownloads() {
    for download in notificationService.downloadingModels {
      if let modelId = download.modelId,
        let model = models.first(where: { $0.id == modelId })
      {
        app.downloadService.cancelDownload(model: model)
      }
    }
    notificationService.cancelTracking()
  }
}

#Preview("Overlay Container") {
  ZStack {
    Brand.surface.ignoresSafeArea()

    VStack {
      Text("Main Content")
        .font(.largeTitle)
    }

    DownloadOverlayContainer()
  }
}
