import SwiftData
import SwiftUI

struct CouncilView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.modelContext) private var modelContext
  @State private var vm: ChatViewModel
  @FocusState private var isInputFocused: Bool

  // Voice State
  @State private var isVoiceRecording = false
  @State private var voiceAudioLevel: Float = 0

  // RAG State
  @State private var showingDocumentPicker = false

  init(conversation: Conversation) {
    _vm = State(initialValue: ChatViewModel(conversation: conversation))
  }

  var body: some View {
    VStack(spacing: 0) {
      // 1. Chat/Transcript Area
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 20) {
            // Disclaimer / Header
            Text("The Council is in session.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.top)

            ForEach(vm.conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })) {
              message in
              MessageBubble(message: message)
                .id(message.id)
            }

            // Spacer for bottom input
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

      // 2. Deliberation Status (Overlay)
      if let council = app.councilService, council.isDeliberating {
        DeliberationStatusView(activeProviders: council.activeProviders)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .padding(.bottom, 8)
      }

      // 3. Input Area (Fully Wired)
      ChatInputView(
        text: $vm.inputText,
        isSending: vm.isSending,
        onSend: { await vm.send() },
        onStop: { Task { await vm.stop() } },
        isFocused: $isInputFocused,
        supportsReasoning: false,
        reasoningMode: $vm.reasoningMode,
        conversationLanguage: .english,
        isVoiceRecording: isVoiceRecording,
        isVoiceAvailable: true,
        isWhisperDownloading: false,  // Assume bundled or downloaded for now
        whisperDownloadProgress: 0,
        isWhisperLoading: false,
        whisperLoadingProgress: 0,
        voiceAudioLevel: voiceAudioLevel,
        onVoiceTap: { handleVoiceTap() },
        onVoiceCancel: {
          isVoiceRecording = false
          Task { await app.voiceTranscriber.stopStreamingTranscription() }
        },
        onTranscriptionStop: nil,
        onAddDocument: { showingDocumentPicker = true }
      )
      .padding(.horizontal)
      .padding(.bottom)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .navigationTitle("BarQi")
    .onAppear {
      vm.setChatService(app.chatService)
      vm.setContext(modelContext)
      vm.setAppModel(app)
    }
    .onReceive(NotificationCenter.default.publisher(for: .generationComplete)) { _ in
      vm.isSending = false
    }
    .fileImporter(
      isPresented: $showingDocumentPicker,
      allowedContentTypes: DocumentImportService.supportedUTTypes,
      allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result {
        Task { await importDocuments(urls) }
      }
    }
  }

  private func handleVoiceTap() {
    if isVoiceRecording {
      // Stop
      isVoiceRecording = false
      Task {
        await app.voiceTranscriber.stopStreamingTranscription()
        vm.inputText = app.voiceTranscriber.streamingTranscription
      }
    } else {
      // Start
      isVoiceRecording = true
      Task {
        try? await app.voiceTranscriber.startStreamingTranscription()
        // Setup poller for transcription updates if needed
        // For now simpler hook
      }
    }
  }

  private func importDocuments(_ urls: [URL]) async {
    for url in urls {
      if let doc = try? await app.documentImportService.importDocument(from: url) {
        try? app.ragService.addDocumentToConversation(doc, conversation: vm.conversation)
      }
    }
  }
}

// Reuse Subviews from previous step
struct MessageBubble: View {
  let message: ChatMessage

  var body: some View {
    HStack(alignment: .bottom, spacing: 12) {
      if message.role == .assistant {
        Image(systemName: "building.columns.fill")  // Council Icon
          .font(.system(size: 16))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(Circle().fill(.blue.gradient))
      } else {
        Spacer()
      }

      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
        if !message.text.isEmpty {
          Text(LocalizedStringKey(message.text))  // Markdown support
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 16)
                .fill(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .foregroundStyle(.primary)
        } else {
          // Empty state (thinking)
          ThinkingIndicator()
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
          .help(id)
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

struct ThinkingIndicator: View {
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
