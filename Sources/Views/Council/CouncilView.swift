import SwiftData
import SwiftUI

struct CouncilView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.modelContext) private var modelContext
  @State private var vm: ChatViewModel
  @FocusState private var isInputFocused: Bool

  init(conversation: Conversation) {
    _vm = State(initialValue: ChatViewModel(conversation: conversation))
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 20) {
            Text("The Council is in session.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.top)

            ForEach(vm.conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })) {
              message in
              MessageBubble(message: message)
                .id(message.id)
            }

            Color.clear.frame(height: 100)
          }
          .padding()
        }
        .onChange(of: vm.conversation.messages.count) { _, _ in
          if let last = vm.conversation.messages.last {
            withAnimation {
              proxy.scrollTo(last.id, anchor: .bottom)
            }
          }
        }
      }

      if let council = app.councilService, council.isDeliberating {
        DeliberationStatusView(activeProviders: council.activeProviders)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .padding(.bottom, 8)
      }

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
    .background(Color(.systemBackground))
    .navigationTitle("BarQi")
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

struct MessageBubble: View {
  let message: ChatMessage

  var body: some View {
    HStack(alignment: .bottom, spacing: 12) {
      if message.role == .assistant {
        Image(systemName: "building.columns.fill")
          .font(.system(size: 16))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(Circle().fill(Color.blue.gradient))
      } else {
        Spacer()
      }

      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
        if !message.text.isEmpty {
          Text(message.text)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 16)
                .fill(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .foregroundStyle(.primary)
        } else {
          CouncilThinkingIndicator()
        }
      }

      if message.role == .user {
        Image(systemName: "person.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
      } else {
        Spacer()
      }
    }
  }
}

struct DeliberationStatusView: View {
  let activeProviders: [String]

  var body: some View {
    HStack(spacing: 20) {
      Text("Deliberating...")
        .font(.caption)
        .bold()
        .foregroundStyle(.secondary)

      ForEach(activeProviders, id: \.self) { id in
        Image(systemName: iconFor(id: id))
          .symbolEffect(.pulse.byLayer)
          .foregroundStyle(.blue)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(Capsule())
  }

  func iconFor(id: String) -> String {
    switch id {
    case "gemini": return "sparkles"
    case "gpt4": return "bolt"
    case "claude": return "brain"
    case "deepseek": return "eye"
    default: return "circle"
    }
  }
}

struct CouncilThinkingIndicator: View {
  @State private var opacity: Double = 0.3

  var body: some View {
    HStack(spacing: 4) {
      Circle().frame(width: 6, height: 6)
      Circle().frame(width: 6, height: 6)
      Circle().frame(width: 6, height: 6)
    }
    .foregroundStyle(.secondary)
    .onAppear {
      withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
        opacity = 1.0
      }
    }
    .opacity(opacity)
    .padding(12)
    .background(Color.gray.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}
