import Foundation
import SwiftData

@Model
final class Document {
  @Attribute(.unique) var id: UUID
  var name: String
  var url: URL?
  var createdAt: Date

  init(id: UUID = UUID(), name: String, url: URL? = nil) {
    self.id = id
    self.name = name
    self.url = url
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
}

protocol VectorStoreService: Sendable {
  func searchSimilar(queryEmbedding: [Float], topK: Int) async throws -> [VectorSearchResult]
}

final class MockEmbeddingService: EmbeddingService {
  func generateEmbedding(for text: String) async throws -> [Float] { [0.0] }
}

final class MockVectorStoreService: VectorStoreService {
  func searchSimilar(queryEmbedding: [Float], topK: Int) async throws -> [VectorSearchResult] { [] }
}
