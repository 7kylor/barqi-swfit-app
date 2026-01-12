import Foundation
import SwiftData

enum Preset: String, Codable, CaseIterable, Sendable, Identifiable {
  var id: String { rawValue }
  case general = "general"
  case creative = "creative"
  case code = "code"
  case academic = "academic"
  case professional = "professional"

  var displayName: String {
    switch self {
    case .general: return "General"
    case .creative: return "Creative"
    case .code: return "Code"
    case .academic: return "Academic"
    case .professional: return "Professional"
    }
  }

  var icon: String {
    switch self {
    case .general: return "sparkles"
    case .creative: return "paintpalette"
    case .code: return "chevron.left.forwardslash.chevron.right"
    case .academic: return "graduationcap"
    case .professional: return "briefcase"
    }
  }
}

enum DocumentStatus: String, Codable, Sendable {
  case imported = "imported"
  case processing = "processing"
  case processed = "processed"
  case failed = "failed"
}

protocol DocumentParserService: Sendable {
  func parseText(from document: Document) throws -> String
}

protocol TextChunkingService: Sendable {
  func chunkText(_ text: String) -> [String]
  func createDocumentChunks(for documentId: UUID, from chunks: [String], modelContext: ModelContext)
    throws -> [DocumentChunk]
}

struct PS {
  static let choose_how_to_use = "Choose how to use BarQi"
}

final class MockDocumentParserService: DocumentParserService {
  func parseText(from document: Document) throws -> String { "" }
}

final class MockTextChunkingService: TextChunkingService {
  func chunkText(_ text: String) -> [String] { [] }
  func createDocumentChunks(for documentId: UUID, from chunks: [String], modelContext: ModelContext)
    throws -> [DocumentChunk]
  { [] }
}
