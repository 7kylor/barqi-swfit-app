import Foundation
import SwiftData

@Model
final class Document {
  @Attribute(.unique) var id: UUID
  var name: String
  var url: URL?
  var createdAt: Date
  var statusRaw: String = DocumentStatus.imported.rawValue
  var processedAt: Date?
  var chunkCount: Int = 0
  var sizeBytes: Int64 = 0
  var fileType: String = "pdf"

  var status: DocumentStatus {
    get { DocumentStatus(rawValue: statusRaw) ?? .imported }
    set { statusRaw = newValue.rawValue }
  }

  var filePath: String {
    url?.path ?? ""
  }

  init(
    id: UUID = UUID(),
    name: String,
    url: URL? = nil,
    filePath: String? = nil,
    fileType: String = "pdf",
    sizeBytes: Int64 = 0,
    status: DocumentStatus = .imported,
    processedAt: Date? = nil,
    chunkCount: Int = 0
  ) {
    self.id = id
    self.name = name
    if let filePath = filePath {
      self.url = URL(fileURLWithPath: filePath)
    } else {
      self.url = url
    }
    self.fileType = fileType
    self.sizeBytes = sizeBytes
    self.statusRaw = status.rawValue
    self.processedAt = processedAt
    self.chunkCount = chunkCount
    self.createdAt = Date()
  }
}

@Model
final class DocumentChunk {
  @Attribute(.unique) var id: UUID
  var documentId: UUID
  var text: String
  var index: Int

  init(id: UUID = UUID(), documentId: UUID, text: String, index: Int) {
    self.id = id
    self.documentId = documentId
    self.text = text
    self.index = index
  }
}

@Model
final class ConversationDocument {
  var conversationId: UUID
  var documentId: UUID

  init(conversationId: UUID, documentId: UUID) {
    self.conversationId = conversationId
    self.documentId = documentId
  }
}

struct VectorSearchResult: Sendable, Equatable {
  let chunkId: UUID
  let documentId: UUID
  let text: String
  var similarityScore: Float

  init(chunkId: UUID, documentId: UUID, text: String, similarityScore: Float) {
    self.chunkId = chunkId
    self.documentId = documentId
    self.text = text
    self.similarityScore = similarityScore
  }
}

struct RetrievedChunk: Sendable {
  let chunk: DocumentChunk
  let document: Document
  let similarityScore: Float

  init(chunk: DocumentChunk, document: Document, similarityScore: Float) {
    self.chunk = chunk
    self.document = document
    self.similarityScore = similarityScore
  }
}

protocol EmbeddingService: Sendable {
  func generateEmbedding(for text: String) async throws -> [Float]
  func generateEmbeddings(for texts: [String]) async throws -> [[Float]]
}

protocol VectorStoreService: Sendable {
  func searchSimilar(queryEmbedding: [Float], topK: Int) async throws -> [VectorSearchResult]
  func storeChunk(_ chunk: DocumentChunk, embedding: [Float]) async throws
}

final class MockEmbeddingService: EmbeddingService {
  func generateEmbedding(for text: String) async throws -> [Float] { [0.0] }
  func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
    texts.map { _ in [0.0] }
  }
}

final class MockVectorStoreService: VectorStoreService {
  func searchSimilar(queryEmbedding: [Float], topK: Int) async throws -> [VectorSearchResult] { [] }
  func storeChunk(_ chunk: DocumentChunk, embedding: [Float]) async throws {}
}
