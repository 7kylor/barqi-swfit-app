import Foundation
import Metal
#if os(iOS)
  import UIKit
#endif

/// Collects comprehensive diagnostics information for error reporting
struct DiagnosticsCollector {
  /// Collects complete diagnostics including app info, device info, error details, and model info
  @MainActor
  static func collectDiagnostics(
    error: Error,
    model: AIModel? = nil,
    appModel: AppModel? = nil
  ) async -> String {
    var diagnostics: [String] = []

    // App Information
    diagnostics.append("=== APP INFORMATION ===")
    diagnostics.append("App Version: \(appVersion)")
    diagnostics.append("Build Number: \(buildNumber)")
    diagnostics.append("Bundle ID: \(bundleIdentifier)")
    diagnostics.append("Build Configuration: \(buildConfiguration)")
    diagnostics.append("Minimum iOS Version: \(minimumOSVersion)")
    diagnostics.append("")

    // Device Information
    diagnostics.append("=== DEVICE INFORMATION ===")
    #if os(iOS)
      diagnostics.append("Device Model: \(UIDevice.current.model)")
      diagnostics.append("Device Name: \(UIDevice.current.name)")
      diagnostics.append("System Name: \(UIDevice.current.systemName)")
      diagnostics.append("System Version: \(UIDevice.current.systemVersion)")
      diagnostics.append("Device Identifier: \(deviceIdentifier)")
      diagnostics.append("Device RAM: \(DeviceRAMDetector.getDeviceRAMGB()) GB")
      diagnostics.append("Is Simulator: \(isSimulator ? "Yes" : "No")")
      diagnostics.append("Interface Idiom: \(interfaceIdiom)")
      if let availableStorage = StorageManager.getAvailableDiskSpace() {
        diagnostics.append(
          "Available Storage: \(ByteCountFormatterUtil.format(bytes: availableStorage))")
      }
      if let totalStorage = StorageManager.getTotalDiskSpace() {
        diagnostics.append(
          "Total Storage: \(ByteCountFormatterUtil.format(bytes: totalStorage))")
      }
    #endif
    diagnostics.append("")
    
    // GPU / Metal Information
    diagnostics.append("=== GPU / METAL INFORMATION ===")
    if let device = MTLCreateSystemDefaultDevice() {
      diagnostics.append("Metal Device: \(device.name)")
      diagnostics.append("Metal GPU Family: \(getMetalGPUFamily(device))")
      diagnostics.append("Recommended Max Working Set: \(ByteCountFormatterUtil.format(bytes: Int64(device.recommendedMaxWorkingSetSize)))")
      diagnostics.append("Max Buffer Length: \(ByteCountFormatterUtil.format(bytes: Int64(device.maxBufferLength)))")
      diagnostics.append("Has Unified Memory: \(device.hasUnifiedMemory ? "Yes" : "No")")
      diagnostics.append("Supports Ray Tracing: \(device.supportsRaytracing ? "Yes" : "No")")
      #if os(iOS)
      diagnostics.append("Current Allocated Size: \(ByteCountFormatterUtil.format(bytes: Int64(device.currentAllocatedSize)))")
      #endif
    } else {
      diagnostics.append("Metal Device: NOT AVAILABLE")
    }
    diagnostics.append("GPU Memory Detector - Recommended: \(GPUMemoryDetector.getRecommendedGPUMemoryMB()) MB")
    diagnostics.append("GPU Memory Detector - Usable: \(GPUMemoryDetector.getUsableGPUMemoryMB()) MB")
    diagnostics.append("")
    
    // Inference Engine Status
    diagnostics.append("=== INFERENCE ENGINE STATUS ===")
    diagnostics.append("Engine Type: MLX (Apple Silicon optimized)")
    diagnostics.append("")

    // Error Information (Enhanced)
    diagnostics.append("=== ERROR INFORMATION ===")
    diagnostics.append("Error Type: \(type(of: error))")
    diagnostics.append("Error Description: \(error.localizedDescription)")
    diagnostics.append("Error Debug Description: \(String(describing: error))")

    // Handle InferenceEngineError specifically
    if let inferenceError = error as? InferenceEngineError {
      diagnostics.append("Inference Error Case: \(inferenceError)")
      diagnostics.append("Inference Error Details: \(getInferenceErrorDetails(inferenceError))")
    }

    if let nsError = error as NSError? {
      diagnostics.append("Error Domain: \(nsError.domain)")
      diagnostics.append("Error Code: \(nsError.code)")
      if !nsError.userInfo.isEmpty {
        diagnostics.append("Error User Info:")
        for (key, value) in nsError.userInfo {
          diagnostics.append("  \(key): \(value)")
        }
      }
      if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
        diagnostics.append("Underlying Error: \(underlyingError)")
        diagnostics.append(
          "Underlying Error Description: \(underlyingError.localizedDescription)")
      }
    }
    diagnostics.append("")

    // Apple Foundation Models Status (Enhanced)
    diagnostics.append("=== APPLE FOUNDATION MODELS STATUS ===")
    diagnostics.append("SDK Present: \(AppleFeatureGates.isSDKPresent)")
    diagnostics.append("Feature Enabled: \(AppleFeatureGates.isEnabled)")
    diagnostics.append("Is Available: \(AppleFeatureGates.isAvailable)")
    if let reason = AppleFeatureGates.unavailabilityReason {
      diagnostics.append("Unavailability Reason: \(reason)")
    } else {
      diagnostics.append("Unavailability Reason: None (Available)")
    }
    let supportedLanguages = AppleFeatureGates.supportedLanguages
    if !supportedLanguages.isEmpty {
      diagnostics.append("Supported Languages: \(supportedLanguages.joined(separator: ", "))")
      diagnostics.append("Supported Language Count: \(supportedLanguages.count)")
    } else {
      diagnostics.append("Supported Languages: Unable to query (model may be unavailable)")
    }
    
    // Note: Detailed Foundation Models availability is already captured above via AppleFeatureGates
    
    diagnostics.append("")

    // Model Information (if available)
    if let model = model {
      diagnostics.append("=== MODEL INFORMATION ===")
      diagnostics.append("Model Name: \(model.name)")
      diagnostics.append("Model ID: \(model.id.uuidString)")
      diagnostics.append("Model Status: \(model.status)")
      diagnostics.append("Model Provider: \(model.provider)")
      diagnostics.append("Model Format: \(model.format)")
      diagnostics.append("Model Size: \(ByteCountFormatterUtil.format(bytes: model.sizeBytes))")
      diagnostics.append("Model Size (bytes): \(model.sizeBytes)")
      diagnostics.append(
        "Required RAM: \(model.requiredRAMGB.map { "\($0) GB" } ?? "Not specified")")
      diagnostics.append("Context Length: \(model.contextLength)")
      diagnostics.append("GPU Layers (configured): \(model.gpuLayers)")
      if let quantization = model.quantization {
        diagnostics.append("Quantization: \(quantization)")
      }
      diagnostics.append("Chat Template: \(model.chatTemplate)")
      if let repoId = model.repoId {
        diagnostics.append("HuggingFace Repo: \(repoId)")
      }
      if let filename = model.filename {
        diagnostics.append("Filename: \(filename)")
      }
      diagnostics.append("")
      
      // Calculated GPU Configuration
      diagnostics.append("=== CALCULATED GPU CONFIGURATION ===")
      let optimalConfig = GPUMemoryDetector.calculateOptimalGPUConfig(
        modelSizeBytes: model.sizeBytes,
        totalLayers: 32,
        requestedLayers: model.gpuLayers
      )
      diagnostics.append("Optimal GPU Layers: \(optimalConfig.gpuLayers)")
      diagnostics.append("Use Memory Mapping (mmap): \(optimalConfig.useMmap ? "Yes" : "No")")
      diagnostics.append("Model-to-GPU Ratio: \(String(format: "%.2f", Double(model.sizeBytes) / Double(max(1, GPUMemoryDetector.getRecommendedGPUMemoryMB() * 1_048_576))))")
      diagnostics.append("")
      
      // File System Details
      diagnostics.append("=== MODEL FILE DETAILS ===")
      if let localPath = model.localPath {
        diagnostics.append("Local Path: \(localPath)")
        let url = URL(fileURLWithPath: localPath)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory)
        diagnostics.append("File/Directory Exists: \(exists)")
        diagnostics.append("Is Directory: \(isDirectory.boolValue)")

        if exists {
          if isDirectory.boolValue {
            // MLX models are directories that contain config.json.
            diagnostics.append("Type: MLX Model Directory")

            let configInPath = url.appendingPathComponent("config.json").path
            let configInSubdir = url.appendingPathComponent("mlx/config.json").path
            let hasConfigInPath = FileManager.default.fileExists(atPath: configInPath)
            let hasConfigInSubdir = FileManager.default.fileExists(atPath: configInSubdir)
            diagnostics.append("config.json (root): \(hasConfigInPath)")
            diagnostics.append("config.json (mlx/): \(hasConfigInSubdir)")

            let completeSentinel = url.appendingPathComponent(".complete").path
            let hasComplete = FileManager.default.fileExists(atPath: completeSentinel)
            diagnostics.append(".complete sentinel: \(hasComplete)")
          } else {
            // Legacy single-file model (e.g. GGUF). No longer supported.
            diagnostics.append("Type: Legacy single-file model (unsupported)")
          }

          if let attrs = try? FileManager.default.attributesOfItem(atPath: localPath) {
            if let size = (attrs[.size] as? NSNumber)?.int64Value {
              diagnostics.append(
                "Actual File Size: \(ByteCountFormatterUtil.format(bytes: size))")
              diagnostics.append("Actual File Size (bytes): \(size)")
              // Check if file size matches expected
              if size != model.sizeBytes && model.sizeBytes > 0 {
                let diff = abs(size - model.sizeBytes)
                diagnostics.append(
                  "SIZE MISMATCH: Expected \(model.sizeBytes) bytes, got \(size) bytes (diff: \(diff) bytes)")
              } else {
                diagnostics.append("Size Validation: PASSED")
              }
            }
            if let creationDate = attrs[.creationDate] as? Date {
              diagnostics.append("File Created: \(formatDate(creationDate))")
            }
            if let modificationDate = attrs[.modificationDate] as? Date {
              diagnostics.append("File Modified: \(formatDate(modificationDate))")
            }
            if let fileType = attrs[.type] as? FileAttributeType {
              diagnostics.append("File Type: \(fileType.rawValue)")
            }
            if let posixPermissions = attrs[.posixPermissions] as? NSNumber {
              diagnostics.append("POSIX Permissions: \(String(format: "%o", posixPermissions.intValue))")
            }
          }
          // Check file readability
          let isReadable = FileManager.default.isReadableFile(atPath: localPath)
          diagnostics.append("File Readable: \(isReadable ? "Yes" : "NO - PERMISSION ISSUE")")
        } else {
          diagnostics.append("FILE NOT FOUND - Model needs to be re-downloaded")
          // Check parent directory
          let parentDir = (localPath as NSString).deletingLastPathComponent
          let parentExists = FileManager.default.fileExists(atPath: parentDir)
          diagnostics.append("Parent Directory Exists: \(parentExists)")
        }
      } else {
        diagnostics.append("Local Path: Not available (model not downloaded)")
      }
      if let downloadURL = model.downloadURL {
        diagnostics.append("Download URL: \(downloadURL.absoluteString)")
      }
      if let sha256 = model.sha256 {
        diagnostics.append("Expected SHA256: \(sha256)")
      }
      if let etag = model.etag {
        diagnostics.append("ETag: \(etag)")
      }
      if let lastError = model.lastError {
        diagnostics.append("Last Model Error: \(lastError)")
      }
      diagnostics.append("")
    }

    // Engine Information (if available)
    if let appModel = appModel {
      diagnostics.append("=== ENGINE INFORMATION ===")
      if let loadedModelId = appModel.engine.loadedModelId() {
        diagnostics.append("Currently Loaded Model ID: \(loadedModelId.uuidString)")
      } else {
        diagnostics.append("Currently Loaded Model ID: None")
      }
      diagnostics.append("Engine Type: \(type(of: appModel.engine))")
      diagnostics.append("Engine Is Loaded: \(appModel.engine.isLoaded())")
      
      // Add context window information for Apple Foundation Models
      #if canImport(FoundationModels)
      if let appleEngine = appModel.engine as? FoundationModelsEngine {
        let contextInfo = appleEngine.getContextWindowInfo()
        diagnostics.append("Context Window Usage: \(contextInfo.used)/\(contextInfo.estimated) chars (\(String(format: "%.1f", contextInfo.percentage))%)")
      }
      #endif
      diagnostics.append("")
    }

    // Memory Pressure & Usage
    diagnostics.append("=== MEMORY STATUS ===")
    let memoryInfo = getMemoryInfo()
    diagnostics.append("Physical Memory: \(ByteCountFormatterUtil.format(bytes: Int64(ProcessInfo.processInfo.physicalMemory)))")
    diagnostics.append("App Memory Used: \(ByteCountFormatterUtil.format(bytes: Int64(memoryInfo.used)))")
    diagnostics.append("App Memory Footprint: \(ByteCountFormatterUtil.format(bytes: Int64(memoryInfo.footprint)))")
    diagnostics.append("Memory Pressure Level: \(memoryPressureLevel)")
    diagnostics.append("")
    
    // System Information
    diagnostics.append("=== SYSTEM INFORMATION ===")
    diagnostics.append("Process Info:")
    diagnostics.append("  Process Name: \(ProcessInfo.processInfo.processName)")
    diagnostics.append("  Process ID: \(ProcessInfo.processInfo.processIdentifier)")
    diagnostics.append("  Host Name: \(ProcessInfo.processInfo.hostName)")
    diagnostics.append(
      "  Physical Memory: \(ByteCountFormatterUtil.format(bytes: Int64(ProcessInfo.processInfo.physicalMemory)))"
    )
    diagnostics.append("  Processor Count: \(ProcessInfo.processInfo.processorCount)")
    diagnostics.append("  Active Processor Count: \(ProcessInfo.processInfo.activeProcessorCount)")
    diagnostics.append(
      "  Low Power Mode: \(ProcessInfo.processInfo.isLowPowerModeEnabled ? "Yes" : "No")")
    diagnostics.append(
      "  Thermal State: \(thermalStateDescription(ProcessInfo.processInfo.thermalState))")
    diagnostics.append("  System Uptime: \(formatUptime(ProcessInfo.processInfo.systemUptime))")
    diagnostics.append("")
    
    // Locale & Language Settings
    diagnostics.append("=== LOCALE & LANGUAGE ===")
    diagnostics.append("Current Locale: \(Locale.current.identifier)")
    diagnostics.append("Preferred Languages: \(Locale.preferredLanguages.joined(separator: ", "))")
    diagnostics.append("Calendar: \(Calendar.current.identifier.debugDescription)")
    diagnostics.append("Timezone: \(TimeZone.current.identifier)")
    diagnostics.append("Is 24-Hour Time: \(is24HourTime ? "Yes" : "No")")
    diagnostics.append("")
    
    // App Directories
    diagnostics.append("=== APP DIRECTORIES ===")
    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      diagnostics.append("Documents: \(documentsURL.path)")
    }
    if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      diagnostics.append("App Support: \(appSupportURL.path)")
      // List models directory
      let modelsDir = appSupportURL.appendingPathComponent("Models")
      if FileManager.default.fileExists(atPath: modelsDir.path) {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelsDir.path) {
          diagnostics.append("Models Directory Contents: \(contents.count) items")
          for item in contents.prefix(10) {
            let itemPath = modelsDir.appendingPathComponent(item).path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: itemPath),
               let size = attrs[.size] as? Int64 {
              diagnostics.append("  - \(item): \(ByteCountFormatterUtil.format(bytes: size))")
            } else {
              diagnostics.append("  - \(item)")
            }
          }
          if contents.count > 10 {
            diagnostics.append("  ... and \(contents.count - 10) more items")
          }
        }
      } else {
        diagnostics.append("Models Directory: Not created yet")
      }
    }
    diagnostics.append("")

    // Recent Logs (Critical for debugging)
    diagnostics.append("=== RECENT LOGS (Last 50 entries) ===")
    let recentLogs = await Logger.getRecentLogs(count: 50)
    if recentLogs.isEmpty {
      diagnostics.append("No recent logs available")
    } else {
      for entry in recentLogs {
        diagnostics.append(entry.formatted)
      }
    }
    diagnostics.append("")

    // Timestamp
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .full
    formatter.locale = Locale(identifier: "en_US_POSIX")
    diagnostics.append("=== TIMESTAMP ===")
    diagnostics.append("Reported At: \(formatter.string(from: Date()))")
    diagnostics.append("Timezone: \(TimeZone.current.identifier)")

    return diagnostics.joined(separator: "\n")
  }

  // MARK: - Private Helpers

  private static var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
  }

  private static var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
  }

  private static var bundleIdentifier: String {
    Bundle.main.bundleIdentifier ?? "Unknown"
  }
  
  private static var buildConfiguration: String {
    #if DEBUG
    return "Debug"
    #else
    return "Release"
    #endif
  }
  
  private static var minimumOSVersion: String {
    Bundle.main.infoDictionary?["MinimumOSVersion"] as? String ?? "Unknown"
  }
  
  private static var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }
  
  @MainActor
  private static var interfaceIdiom: String {
    #if os(iOS)
    switch UIDevice.current.userInterfaceIdiom {
    case .phone: return "iPhone"
    case .pad: return "iPad"
    case .tv: return "Apple TV"
    case .carPlay: return "CarPlay"
    case .mac: return "Mac (Catalyst)"
    case .vision: return "Vision Pro"
    default: return "Unknown"
    }
    #else
    return "macOS"
    #endif
  }

  private static var deviceIdentifier: String {
    #if os(iOS)
      var systemInfo = utsname()
      uname(&systemInfo)
      let machineMirror = Mirror(reflecting: systemInfo.machine)
      let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
      return identifier
    #else
      return "Unknown"
    #endif
  }

  private static func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "Nominal"
    case .fair: return "Fair"
    case .serious: return "Serious"
    case .critical: return "Critical"
    @unknown default: return "Unknown"
    }
  }
  
  private static func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
  
  private static func formatUptime(_ uptime: TimeInterval) -> String {
    let hours = Int(uptime) / 3600
    let minutes = (Int(uptime) % 3600) / 60
    let seconds = Int(uptime) % 60
    if hours > 24 {
      let days = hours / 24
      let remainingHours = hours % 24
      return "\(days)d \(remainingHours)h \(minutes)m"
    }
    return "\(hours)h \(minutes)m \(seconds)s"
  }
  
  private static var is24HourTime: Bool {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    let dateString = formatter.string(from: Date())
    return !dateString.contains("AM") && !dateString.contains("PM")
  }
  
  private static var memoryPressureLevel: String {
    // Use dispatch source to check memory pressure
    // This is a simplified check based on available memory ratio
    let memInfo = getMemoryInfo()
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    let usedRatio = Double(memInfo.footprint) / Double(totalMemory)
    
    if usedRatio < 0.5 {
      return "Normal (\(String(format: "%.1f", usedRatio * 100))% used)"
    } else if usedRatio < 0.7 {
      return "Warning (\(String(format: "%.1f", usedRatio * 100))% used)"
    } else {
      return "Critical (\(String(format: "%.1f", usedRatio * 100))% used)"
    }
  }
  
  private static func getMemoryInfo() -> (used: UInt64, footprint: UInt64) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    
    if result == KERN_SUCCESS {
      return (used: info.resident_size, footprint: info.resident_size)
    }
    return (used: 0, footprint: 0)
  }
  
  private static func getMetalGPUFamily(_ device: MTLDevice) -> String {
    var families: [String] = []
    
    // Check for Apple GPU families (common on iOS)
    if device.supportsFamily(.apple7) {
      families.append("Apple7+")
    } else if device.supportsFamily(.apple6) {
      families.append("Apple6")
    } else if device.supportsFamily(.apple5) {
      families.append("Apple5")
    } else if device.supportsFamily(.apple4) {
      families.append("Apple4")
    } else if device.supportsFamily(.apple3) {
      families.append("Apple3")
    }
    
    // Check for common feature sets
    if device.supportsFamily(.common3) {
      families.append("Common3")
    } else if device.supportsFamily(.common2) {
      families.append("Common2")
    }
    
    return families.isEmpty ? "Unknown" : families.joined(separator: ", ")
  }

  private static func getInferenceErrorDetails(_ error: InferenceEngineError) -> String {
    switch error {
    case .modelNotFound:
      return
        "The model file could not be found on disk. This may indicate the file was deleted, moved, or the download was incomplete."
    case .invalidModelFormat:
      return
        "The model file format is invalid or unsupported. This could be due to a corrupted download, incompatible model format, or unsupported language/locale."
    case .modelNotLoaded:
      return
        "No model is currently loaded in memory. For Apple models, this may indicate Apple Intelligence is not enabled, the device is not eligible, or the model is not ready."
    case .outOfMemory:
      return
        "The device ran out of memory while loading or running the model. Try closing other apps or using a smaller model."
    case .generationCancelled:
      return
        "The generation was cancelled, either by user action or due to a concurrent request conflict."
    case .contextLengthExceeded:
      return
        "The conversation context exceeded the model's maximum context length. Try starting a new conversation."
    case .invalidFormat(let message):
      return "Invalid format: \(message)"
    case .contentBlocked:
      return
        "The content was blocked by safety filters. The model's guardrails prevented generating a response for this input."
    case .unsupportedLanguage:
      return
        "The requested language is not supported by this model. Try using a different language or model."
    }
  }

  /// Opens email client with pre-filled diagnostics
  @MainActor
  static func sendDiagnosticsEmail(
    error: Error,
    model: AIModel? = nil,
    appModel: AppModel? = nil,
    recipientEmail: String = "hello@taher.ai"
  ) async {
    let diagnostics = await collectDiagnostics(error: error, model: model, appModel: appModel)

    let subject = "Mawj Error Report - \(type(of: error))"
    let body = """
      Hi,

      I encountered an error in Mawj. Please find the complete diagnostics below:

      \(diagnostics)

      Please let me know if you need any additional information.

      Thanks!
      """

    let encodedSubject =
      subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    #if os(iOS)
      if let url = URL(
        string: "mailto:\(recipientEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
      {
        if UIApplication.shared.canOpenURL(url) {
          await UIApplication.shared.open(url)
        } else {
          // Fallback: copy diagnostics to clipboard and show notification
          UIPasteboard.general.string = diagnostics
          NotificationCenter.default.post(
            name: .showToast,
            object: [
              "message": "Diagnostics copied to clipboard. Please email to \(recipientEmail)",
              "kind": "info",
            ]
          )
        }
      }
    #endif
  }

  /// Copy diagnostics to clipboard without opening email
  @MainActor
  static func copyDiagnosticsToClipboard(
    error: Error,
    model: AIModel? = nil,
    appModel: AppModel? = nil
  ) async -> String {
    let diagnostics = await collectDiagnostics(error: error, model: model, appModel: appModel)
    #if os(iOS)
      UIPasteboard.general.string = diagnostics
    #endif
    return diagnostics
  }
}
