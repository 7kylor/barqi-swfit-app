import Observation
import SwiftData
import SwiftUI

struct ChatView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.modelContext) private var modelContext
  @State private var vm: ChatViewModel
  @FocusState private var isInputFocused: Bool

  // Stubs for missing services/states
  @State private var toastCenter = ToastCenter()  // We need ToastCenter implementation or stub
  @State private var scrollProxy: ScrollViewProxy?
  @State private var isNearBottom: Bool = true
  @State private var lastMessageId: UUID?

  init(conversation: Conversation) {
    _vm = State(initialValue: ChatViewModel(conversation: conversation))
  }

  var body: some View {
    ChatListView(
      conversation: vm.conversation,
      isSending: vm.isSending,
      toast: toastCenter,
      scrollProxy: $scrollProxy,
      isNearBottom: $isNearBottom,
      lastMessageId: $lastMessageId,
      onSpeak: { _ in },
      speakingMessageId: nil
    )
    .safeAreaInset(edge: .bottom) {
      ChatInputView(
        text: $vm.inputText,
        isSending: vm.isSending,
        onSend: { Task { await vm.send() } },
        onStop: { Task { await vm.stop() } },
        isFocused: $isInputFocused
      )
      .padding(.horizontal)
      .padding(.bottom)
    }
    .navigationTitle(vm.conversation.title)
    .onAppear {
      vm.setChatService(app.chatService)
      vm.setContext(modelContext)
      vm.setAppModel(app)
    }
    .onReceive(NotificationCenter.default.publisher(for: .generationComplete)) { _ in
      vm.isSending = false
    }
  }
}

// Stub for ToastCenter if not copied
@Observable
class ToastCenter {
  func show(_ message: String, kind: ToastKind = .info, actionTitle: String? = nil) {}
}

enum ToastKind {
  case info, success, warning, error
}
