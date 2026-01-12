import Foundation
import SwiftData

@Model
final class Preset {
  @Attribute(.unique) var id: String
  var name: String

  init(id: String = UUID().uuidString, name: String) {
    self.id = id
    self.name = name
  }
}

protocol DocumentParserService: Sendable {
  func parse(url: URL) async throws -> String
}

protocol TextChunkingService: Sendable {
  func chunk(text: String) -> [String]
}

final class MockDocumentParserService: DocumentParserService {
  func parse(url: URL) async throws -> String { "" }
}

final class MockTextChunkingService: TextChunkingService {
  func chunk(text: String) -> [String] { [] }
}
