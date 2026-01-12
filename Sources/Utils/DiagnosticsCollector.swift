import Foundation
import SwiftUI

struct DiagnosticsCollector {
  @MainActor
  static func collectDiagnostics(
    error: Error,
    model: AIModel? = nil,
    appModel: AppModel? = nil
  ) async -> String {
    var diagnostics: [String] = []

    diagnostics.append("=== APP INFORMATION ===")
    diagnostics.append("App: BarQi (Council of AI)")
    diagnostics.append(
      "Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
    )
    diagnostics.append("")

    diagnostics.append("=== ERROR INFORMATION ===")
    diagnostics.append("Error: \(error.localizedDescription)")
    diagnostics.append("Type: \(type(of: error))")
    diagnostics.append("")

    if let model = model {
      diagnostics.append("=== MODEL INFORMATION ===")
      diagnostics.append("Model: \(model.name)")
      diagnostics.append("Provider: \(model.providerRaw)")
    }

    return diagnostics.joined(separator: "\n")
  }
}
