import Foundation

#if os(iOS)
  import UIKit
#endif

enum DeviceRAMDetector {
  /// Returns the device's physical RAM capacity in bytes
  /// Uses ProcessInfo for accurate detection on all devices including simulators
  static func getDeviceRAMBytes() -> Int64 {
    // ProcessInfo.physicalMemory works on both iOS and macOS
    // It returns the actual RAM available to the process
    return Int64(ProcessInfo.processInfo.physicalMemory)
  }

  /// Returns the device's physical RAM capacity in GB
  static func getDeviceRAMGB() -> Int {
    let bytes = getDeviceRAMBytes()
    // Use 1024^3 for accurate GB conversion
    return Int(bytes / 1_073_741_824)
  }

  /// Checks if device has at least the specified RAM in GB
  static func hasAtLeastRAM(_ requiredGB: Int) -> Bool {
    return getDeviceRAMGB() >= requiredGB
  }

  /// Checks if device can support models larger than 4GB
  /// Requires 8GB+ RAM for comfortable operation
  static func canSupportLargeModels() -> Bool {
    return hasAtLeastRAM(8)
  }

  /// Checks if device meets gaming-tier performance requirements at runtime
  /// Returns true for devices with 6GB+ RAM
  static func meetsGamingTierPerformance() -> Bool {
    return hasAtLeastRAM(6)
  }

  /// Returns available memory for model loading (accounts for system overhead)
  /// Uses ~70% of physical RAM as usable for models
  static func getAvailableRAMForModelsGB() -> Int {
    let totalGB = getDeviceRAMGB()
    // Reserve ~30% for system and app overhead
    return max(1, Int(Double(totalGB) * 0.7))
  }
}
