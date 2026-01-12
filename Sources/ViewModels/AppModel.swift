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
  var engine: InferenceEngine

  // Real Services
  var voiceTranscriber = VoiceTranscriptionService()
  var documentImportService: DocumentImportService
  var documentProcessingService = DocumentProcessingService()
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
    self.engine = MockEngine()

    // Initialize RAG
    self.ragService = RAGService(
      modelContext: modelContainer.mainContext,
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
    // In Porting, maybe link this to a real aggregation?
    // For now, keep simple
    conversation.title = "BarQi Session \(Date().formatted(date: .numeric, time: .shortened))"
  }

  func forceReseedModels() {
    // Stub for settings action
  }
}

protocol InferenceEngine {
  func isLoaded() -> Bool
  func loadedModelId() -> String?
}

class MockEngine: InferenceEngine {
  func isLoaded() -> Bool { true }
  func loadedModelId() -> String? { "mock-model" }
}
