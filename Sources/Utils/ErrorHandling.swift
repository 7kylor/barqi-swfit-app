import Foundation

enum BarQiError: Error, LocalizedError, Sendable {
  case generationFailed(underlying: Error?)
  case generationCancelled
  case configurationError(String)
  case networkError(String)

  var errorDescription: String? {
    switch self {
    case .generationFailed(let underlying):
      return "Deliberation failed: \(underlying?.localizedDescription ?? "unknown error")"
    case .generationCancelled:
      return "Deliberation was cancelled"
    case .configurationError(let message):
      return "Configuration error: \(message)"
    case .networkError(let message):
      return "Network error: \(message)"
    }
  }
}

@MainActor
final class ErrorReporter {
  static let shared = ErrorReporter()
  private var errorHistory: [ErrorReport] = []
  private init() {}

  func reportError(
    _ error: Error, context: String? = nil, file: String = #fileID, function: String = #function,
    line: Int = #line
  ) {
    let report = ErrorReport(
      error: error, context: context, timestamp: Date(), file: file, function: function, line: line)
    errorHistory.append(report)
  }
}

struct ErrorReport: Sendable, Identifiable {
  let id = UUID()
  let error: Error
  let context: String?
  let timestamp: Date
  let file: String
  let function: String
  let line: Int
}

struct StorageManager {
  static func cleanupTemporaryFiles() {}
}
