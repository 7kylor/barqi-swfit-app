import Foundation

enum ByteCountFormatterUtil {
  static func format(bytes: Int64) -> String {
    let fmt = ByteCountFormatter()
    fmt.allowedUnits = [.useKB, .useMB, .useGB]
    fmt.countStyle = .file
    return fmt.string(fromByteCount: bytes)
  }

  static func formatPerSecond(bps: Double) -> String {
    guard bps.isFinite && bps >= 0 else { return "0 MB/s" }
    let kb = bps / 1024.0
    let mb = kb / 1024.0
    let gb = mb / 1024.0
    if gb >= 1.0 {
      return String(format: "%.2f GB/s", gb)
    } else if mb >= 1.0 {
      return String(format: "%.1f MB/s", mb)
    } else if kb >= 1.0 {
      return String(format: "%.0f KB/s", kb)
    } else {
      return String(format: "%.0f B/s", bps)
    }
  }
}
