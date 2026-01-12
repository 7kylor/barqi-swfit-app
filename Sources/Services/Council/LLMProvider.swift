import Foundation

protocol LLMProvider: AnyObject, Sendable {
  var id: String { get }
  var name: String { get }
  var icon: String { get }  // System image name or asset
  var description: String { get }  // "The Skeptic", "The Strategist"

  func generate(prompt: String) async throws -> String
}

final class MockProvider: LLMProvider {
  let id: String
  let name: String
  let icon: String
  let description: String

  init(id: String, name: String, icon: String, description: String) {
    self.id = id
    self.name = name
    self.icon = icon
    self.description = description
  }

  func generate(prompt: String) async throws -> String {
    // Simulate network latency
    let delay = Double.random(in: 1.0...3.0)
    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

    return """
      [Testimony from \(name)]
      Analyzing: "\(prompt)"
      Perspective: \(description)

      My analysis suggests that... (Mock reasoning blocks here).
      Core assumption challenged.
      Logic refined.
      """
  }
}
