import Foundation

// MARK: - Unified Error Types
enum MawjError: Error, LocalizedError, Sendable {
  // Model-related errors
  case modelNotFound(String)
  case modelNotLoaded(String)
  case modelCorrupted(String)
  case modelLoadingFailed(String, underlying: Error?)
  case invalidModelFormat(String)

  // Download-related errors
  case downloadFailed(String, underlying: Error?)
  case downloadCancelled(String)
  case downloadResumeDataCorrupted(String)
  case insufficientStorage(required: Int64, available: Int64?)

  // Generation-related errors
  case generationFailed(underlying: Error?)
  case generationCancelled
  case contextLengthExceeded(current: Int, limit: Int)
  case invalidGenerationParameters(String)

  // System-related errors
  case systemResourcesUnavailable(String)
  case fileSystemError(String, underlying: Error?)
  case configurationError(String)

  var errorDescription: String? {
    switch self {
    // Model errors
    case .modelNotFound(let name):
      return "Model '\(name)' not found"
    case .modelNotLoaded(let name):
      return "Model '\(name)' is not loaded"
    case .modelCorrupted(let name):
      return "Model '\(name)' appears to be corrupted"
    case .modelLoadingFailed(let name, let underlying):
      return
        "Failed to load model '\(name)': \(underlying?.localizedDescription ?? "unknown error")"
    case .invalidModelFormat(let format):
      return "Invalid or unsupported model format: '\(format)'"

    // Download errors
    case .downloadFailed(let name, let underlying):
      return "Download failed for '\(name)': \(underlying?.localizedDescription ?? "unknown error")"
    case .downloadCancelled(let name):
      return "Download cancelled for '\(name)'"
    case .downloadResumeDataCorrupted(let name):
      return "Resume data corrupted for '\(name)'"
    case .insufficientStorage(let required, let available):
      let availableStr = available.map { formatBytes($0) } ?? "unknown"
      return "Insufficient storage: need \(formatBytes(required)), have \(availableStr)"

    // Generation errors
    case .generationFailed(let underlying):
      return "Text generation failed: \(underlying?.localizedDescription ?? "unknown error")"
    case .generationCancelled:
      return "Text generation was cancelled"
    case .contextLengthExceeded(let current, let limit):
      return "Context length exceeded: \(current) > \(limit)"
    case .invalidGenerationParameters(let message):
      return "Invalid generation parameters: \(message)"

    // System errors
    case .systemResourcesUnavailable(let resource):
      return "System resource unavailable: \(resource)"
    case .fileSystemError(let operation, let underlying):
      return
        "File system error during \(operation): \(underlying?.localizedDescription ?? "unknown error")"
    case .configurationError(let message):
      return "Configuration error: \(message)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .modelNotFound, .modelNotLoaded:
      return "Please download or select a different model"
    case .modelCorrupted, .modelLoadingFailed:
      return "Try re-downloading the model"
    case .invalidModelFormat:
      return "Please use a supported model format (MLX)"
    case .downloadFailed:
      return "Check your internet connection and try again"
    case .insufficientStorage:
      return "Free up storage space and try again"
    case .generationFailed:
      return "Try adjusting generation parameters or restarting the model"
    case .contextLengthExceeded:
      return "Try using shorter messages or clear the conversation history"
    case .systemResourcesUnavailable:
      return "Close other applications to free up system resources"
    default:
      return nil
    }
  }

  private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

// MARK: - Error Reporter
@MainActor
final class ErrorReporter {
  static let shared = ErrorReporter()

  private var errorHistory: [ErrorReport] = []
  private let maxHistorySize = 50

  private init() {}

  func reportError(
    _ error: Error, context: String? = nil, file: String = #fileID, function: String = #function,
    line: Int = #line
  ) {
    let report = ErrorReport(
      error: error,
      context: context,
      timestamp: Date(),
      file: file,
      function: function,
      line: line
    )

    // Add to history
    errorHistory.append(report)
    if errorHistory.count > maxHistorySize {
      errorHistory.removeFirst()
    }

    // Log the error
    let contextStr = context.map { " [\($0)]" } ?? ""
    Logger.log(
      "Error\(contextStr): \(error.localizedDescription)",
      level: .error,
      category: Logger.general,
      function: function,
      file: file,
      line: line
    )

    // Additional handling for specific error types
    handleSpecificError(error, report: report)
  }

  private func handleSpecificError(_ error: Error, report: ErrorReport) {
    switch error {
    case MawjError.insufficientStorage:
      // Could trigger cleanup of temporary files
      StorageManager.cleanupTemporaryFiles()
    case MawjError.modelCorrupted:
      // Could trigger model re-download
      break
    default:
      break
    }
  }

  func getRecentErrors(limit: Int = 10) -> [ErrorReport] {
    return Array(errorHistory.suffix(limit))
  }

  func clearHistory() {
    errorHistory.removeAll()
  }
}

// MARK: - Error Report
struct ErrorReport: Sendable, Identifiable {
  let id = UUID()
  let error: Error
  let context: String?
  let timestamp: Date
  let file: String
  let function: String
  let line: Int

  var errorType: String {
    String(describing: type(of: error))
  }

  var shortDescription: String {
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    return "\(fileName):\(line) - \(error.localizedDescription)"
  }
}

// MARK: - Result Extensions for Better Error Handling
extension Result where Failure == Error {
  func mapMawjError(_ transform: (Error) -> MawjError) -> Result<Success, MawjError> {
    return mapError(transform)
  }

  func reportError(
    context: String? = nil, file: String = #fileID, function: String = #function, line: Int = #line
  ) -> Self {
    if case .failure(let error) = self {
      Task { @MainActor in
        ErrorReporter.shared.reportError(
          error, context: context, file: file, function: function, line: line)
      }
    }
    return self
  }
}

// MARK: - Async Error Handling Utilities
extension Task where Success == Void, Failure == Error {
  @discardableResult
  static func safeAsync(
    priority: TaskPriority? = nil,
    context: String? = nil,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line,
    operation: @escaping @Sendable () async throws -> Void
  ) -> Task<Void, Never> {
    return Task<Void, Never>(priority: priority) {
      do {
        try await operation()
      } catch {
        await MainActor.run {
          ErrorReporter.shared.reportError(
            error,
            context: context,
            file: file,
            function: function,
            line: line
          )
        }
      }
    }
  }
}
