import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
  let conversation: Conversation
  private var chatService: ChatServing
  private var context: ModelContext?
  private weak var appModel: AppModel?

  // Chat State
  var inputText: String = ""
  var isSending: Bool = false
  var canStop: Bool = false
  var preferredLanguage: DetectedLanguage = .english
  var diagnosticsOverlayVisible: Bool = false
  var reasoningMode: ReasoningMode = .auto
  var supportsReasoning: Bool = false

  // Debounce
  private var lastSendTime: Date = .distantPast
  private let sendDebounceInterval: TimeInterval = 0.5

  init(conversation: Conversation, chatService: ChatServing? = nil, appModel: AppModel? = nil) {
    self.conversation = conversation
    self.chatService = chatService ?? NoopChatService()
    self.appModel = appModel
    self.context = nil

    if let langPref = conversation.languageSettings {
      self.preferredLanguage = langPref.preferredLanguage
    }
  }

  @MainActor
  func send() async {
    let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else { return }

    let now = Date()
    guard now.timeIntervalSince(lastSendTime) >= sendDebounceInterval else { return }
    guard !isSending else { return }

    lastSendTime = now

    // Set sending state
    isSending = true
    canStop = true

    // Clear input
    let text = inputText
    inputText = ""

    conversation.reasoningMode = reasoningMode

    await chatService.sendMessage(text, in: conversation)

    if conversation.messages.count == 1 {
      appModel?.autoNameConversation(conversation)
    }
  }

  @MainActor
  func stop() async {
    await chatService.stopGeneration()
    canStop = false
    isSending = false
  }

  // MARK: - Setup

  @MainActor
  func setContext(_ context: ModelContext) {
    self.context = context
  }

  @MainActor
  func setChatService(_ chatService: ChatServing) {
    self.chatService = chatService
  }

  @MainActor
  func setAppModel(_ appModel: AppModel) {
    self.appModel = appModel
  }
}

private final class NoopChatService: ChatServing {
  func sendMessage(_ text: String, in conversation: Conversation) async {}
  func stopGeneration() async {}
}
