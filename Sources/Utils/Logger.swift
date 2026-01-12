import Foundation
import os.log

/// Centralized logging utility for the app
struct Logger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "MawjSwift"

  // Category-specific loggers
  static let chat = os.Logger(subsystem: subsystem, category: "ChatService")
  static let engine = os.Logger(subsystem: subsystem, category: "InferenceEngine")
  static let model = os.Logger(subsystem: subsystem, category: "ModelManager")
  static let events = os.Logger(subsystem: subsystem, category: "Events")
  static let general = os.Logger(subsystem: subsystem, category: "General")
  static let system = os.Logger(subsystem: subsystem, category: "System")
  static let voice = os.Logger(subsystem: subsystem, category: "Voice")
  static let share = os.Logger(subsystem: subsystem, category: "ShareIngestion")

  /// Log levels for different environments
  enum Level: String {
    case debug = "DEBUG"
    case info = "INFO"
    case error = "ERROR"

    var osLogType: OSLogType {
      switch self {
      case .debug: return .debug
      case .info: return .info
      case .error: return .error
      }
    }
  }

  // MARK: - Log Buffer for Diagnostics

  /// Thread-safe log buffer for collecting recent logs
  private static let logBuffer = LogBuffer(maxEntries: 100)

  /// Log entry structure
  struct LogEntry: Sendable {
    let timestamp: Date
    let level: String
    let category: String
    let message: String
    let file: String
    let line: Int
    let function: String

    var formatted: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
      let timeStr = formatter.string(from: timestamp)
      return "[\(timeStr)] [\(level)] [\(category)] \(file):\(line) \(function) - \(message)"
    }
  }

  /// Thread-safe log buffer
  private actor LogBuffer {
    private var entries: [LogEntry] = []
    private let maxEntries: Int

    init(maxEntries: Int) {
      self.maxEntries = maxEntries
    }

    func append(_ entry: LogEntry) {
      entries.append(entry)
      if entries.count > maxEntries {
        entries.removeFirst()
      }
    }

    func getRecent(count: Int) -> [LogEntry] {
      let startIndex = max(0, entries.count - count)
      return Array(entries[startIndex...])
    }

    func getAll() -> [LogEntry] {
      return entries
    }

    func clear() {
      entries.removeAll()
    }
  }

  /// Get recent log entries for diagnostics
  static func getRecentLogs(count: Int = 50) async -> [LogEntry] {
    await logBuffer.getRecent(count: count)
  }

  /// Get all buffered logs
  static func getAllLogs() async -> [LogEntry] {
    await logBuffer.getAll()
  }

  /// Clear the log buffer
  static func clearLogBuffer() async {
    await logBuffer.clear()
  }

  /// Infer category name from file path
  private static func inferCategory(from file: String) -> String {
    let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent.lowercased()

    if fileName.contains("chat") { return "ChatService" }
    if fileName.contains("engine") || fileName.contains("mlx") || fileName.contains("foundation") {
      return "InferenceEngine"
    }
    if fileName.contains("model") { return "ModelManager" }
    if fileName.contains("event") { return "Events" }
    if fileName.contains("system") || fileName.contains("app") { return "System" }
    if fileName.contains("voice") || fileName.contains("audio") || fileName.contains("transcri")
      || fileName.contains("whisper")
    {
      return "Voice"
    }
    return "General"
  }

  /// Enhanced logging with structured format
  static func log(
    _ message: String,
    level: Level = .info,
    category: os.Logger = general,
    function: String = #function,
    file: String = #fileID,
    line: Int = #line
  ) {
    let fileName = URL(fileURLWithPath: file).lastPathComponent

    // Infer category name from file
    let categoryName = inferCategory(from: file)

    // Add to buffer for diagnostics
    let entry = LogEntry(
      timestamp: Date(),
      level: level.rawValue,
      category: categoryName,
      message: message,
      file: fileName,
      line: line,
      function: function
    )
    Task {
      await logBuffer.append(entry)
    }

    #if DEBUG
      let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
      // Also print to stdout for easy visibility in Xcode/terminal runs
      print(logMessage)
      category.log(level: level.osLogType, "\(logMessage)")
    #else
      // In release builds, only log errors and important info
      if level == .error || level == .info {
        category.log(level: level.osLogType, "\(message)")
      }
    #endif
  }
}

extension Notification.Name {
  static let retryAssistantMessage = Notification.Name("com.taher.Mawj.chat.retry")
  static let diagnosticsUpdate = Notification.Name("com.taher.Mawj.chat.diagnosticsUpdate")
  static let showToast = Notification.Name("com.taher.Mawj.toast.show")
  static let usageIncrementMessage = Notification.Name("com.taher.Mawj.usage.incrementMessage")
  static let presentPaywall = Notification.Name("com.taher.Mawj.paywall.present")
  static let modelLoaded = Notification.Name("com.taher.Mawj.model.loaded")
  static let presetChanged = Notification.Name("com.taher.Mawj.preset.changed")
}

/// Console output suppression utility
struct ConsoleSuppressionUtility {

  /// Suppress common iOS system warnings that don't affect functionality
  static func suppressCommonWarnings() {
    // Redirect stderr to suppress specific warnings
    let devNull = freopen("/dev/null", "w", stderr)
    if devNull != nil {
      // Successfully suppressed stderr warnings
    }
  }

  /// Re-enable console output when needed for debugging
  static func restoreConsoleOutput() {
    // Restore stderr
    freopen("/dev/stderr", "w", stderr)
  }
}
