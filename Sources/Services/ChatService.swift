import Foundation
import SwiftData

protocol ChatServing: AnyObject {
  func sendMessage(_ text: String, in conversation: Conversation) async
  func stopGeneration() async
}

final class OnlineChatService: ChatServing {
  init() {}

  func sendMessage(_ text: String, in conversation: Conversation) async {
    // 1. Create user message
    let userMsg = ChatMessage(role: .user, text: text)
    conversation.messages.append(userMsg)

    // 2. Create assistant placeholder
    let assistantMsg = ChatMessage(role: .assistant, text: "")
    conversation.messages.append(assistantMsg)

    // 3. Mock generation (stream text)
    let mockResponse =
      "This is a response from the online BarQi provider. I am considering your request: \"\(text)\""

    for char in mockResponse {
      try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
      await MainActor.run {
        assistantMsg.text.append(char)
      }
    }

    // Notify completion? Use binding or notification
    NotificationCenter.default.post(name: .generationComplete, object: nil)
  }

  func stopGeneration() async {
    // Implement cancellation
  }
}

// Notification for generation completion
extension Notification.Name {
  static let generationComplete = Notification.Name("generationComplete")
}
