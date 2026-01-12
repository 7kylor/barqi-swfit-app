import Foundation

public struct DownloadNotificationState: Identifiable, Sendable {
  public let id = UUID()
  public let modelId: UUID?
  public let modelName: String
  public let progress: Double
  public let statusText: String
  public let isDownloading: Bool
  public let isPillVisible: Bool
  public let isBannerVisible: Bool
  public let error: String?
  public let speed: Double
  public let bytesDownloaded: Int64
  public let totalBytes: Int64

  public init(
    modelId: UUID? = nil,
    modelName: String,
    progress: Double,
    statusText: String,
    isDownloading: Bool,
    isPillVisible: Bool,
    isBannerVisible: Bool,
    error: String? = nil,
    speed: Double = 0,
    bytesDownloaded: Int64 = 0,
    totalBytes: Int64 = 0
  ) {
    self.modelId = modelId
    self.modelName = modelName
    self.progress = progress
    self.statusText = statusText
    self.isDownloading = isDownloading
    self.isPillVisible = isPillVisible
    self.isBannerVisible = isBannerVisible
    self.error = error
    self.speed = speed
    self.bytesDownloaded = bytesDownloaded
    self.totalBytes = totalBytes
  }

  public var progressPercentage: String {
    "\(Int(progress * 100))%"
  }

  public var formattedSpeed: String {
    let mbps = speed / (1024 * 1024)
    return String(format: "%.1f MB/s", mbps)
  }

  public var formattedProgress: String {
    let downloaded = Double(bytesDownloaded) / (1024 * 1024 * 1024)
    let total = Double(totalBytes) / (1024 * 1024 * 1024)
    return String(format: "%.1f / %.1f GB", downloaded, total)
  }
}

public struct AggregatedDownloadState: Sendable {
  public let totalDownloads: Int
  public let completedDownloads: Int
  public let overallProgress: Double
  public let totalBytesDownloaded: Int64
  public let totalBytesExpected: Int64
  public let isAnyDownloading: Bool
  public let primaryModelName: String

  public init(
    totalDownloads: Int = 0,
    completedDownloads: Int = 0,
    overallProgress: Double = 0,
    totalBytesDownloaded: Int64 = 0,
    totalBytesExpected: Int64 = 0,
    isAnyDownloading: Bool = false,
    primaryModelName: String = ""
  ) {
    self.totalDownloads = totalDownloads
    self.completedDownloads = completedDownloads
    self.overallProgress = overallProgress
    self.totalBytesDownloaded = totalBytesDownloaded
    self.totalBytesExpected = totalBytesExpected
    self.isAnyDownloading = isAnyDownloading
    self.primaryModelName = primaryModelName
  }

  public static let idle = AggregatedDownloadState()

  public var formattedProgress: String {
    let downloaded = Double(totalBytesDownloaded) / (1024 * 1024 * 1024)
    let expected = Double(totalBytesExpected) / (1024 * 1024 * 1024)
    return String(format: "%.1f / %.1f GB", downloaded, expected)
  }
}
