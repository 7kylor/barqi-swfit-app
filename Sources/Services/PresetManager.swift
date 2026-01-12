import Foundation
import Observation

@Observable
final class PresetManager: ObservableObject {
  static let shared = PresetManager()

  var activePreset: Preset = .general

  private init() {}

  func selectPreset(_ preset: Preset) {
    activePreset = preset
  }
}
