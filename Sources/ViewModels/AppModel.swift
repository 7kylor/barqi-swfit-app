import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppModel {
  var chatService: ChatServing
  var subscriptionService = SubscriptionService()
  var usageMeter = UsageMeterObject()
  var modelContainer: ModelContainer

  // Real Services
  var voiceTranscriber = VoiceTranscriptionService()
  var documentImportService: DocumentImportService
  var documentProcessingService: DocumentProcessingService
  var ragService: RAGService
  var ttsService = TextToSpeechService()

  // Expose specific service for UI
  var councilService: CouncilService? {
    return chatService as? CouncilService
  }

  init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
    // Initialize CouncilService
    self.chatService = CouncilService()

    // Initialize RAG
    self.ragService = RAGService(
      modelContext: modelContainer.mainContext,
      embeddingService: MockEmbeddingService(),
      vectorStoreService: MockVectorStoreService()
    )
    self.documentProcessingService = DocumentProcessingService(
      modelContext: modelContainer.mainContext,
      parserService: MockDocumentParserService(),
      chunkingService: MockTextChunkingService(),
      embeddingService: MockEmbeddingService(),
      vectorStoreService: MockVectorStoreService()
    )
    self.documentImportService = DocumentImportService(modelContext: modelContainer.mainContext)
  }

  func createConversation() -> Conversation {
    let conv = Conversation(title: "New Council Session")
    modelContainer.mainContext.insert(conv)
    return conv
  }

  func autoNameConversation(_ conversation: Conversation) {
    conversation.title = "BarQi Session \(Date().formatted(date: .numeric, time: .shortened))"
  }

  func forceReseedModels() {
    // Stub for settings action
  }
}
