import Foundation
import Observation

@Observable
final class PresetManager: ObservableObject {
  static let shared = PresetManager()

  var currentPresetId: String?

  private init() {}
}
