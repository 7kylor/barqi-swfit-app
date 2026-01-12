import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct ChatListView: View {
  let conversation: Conversation
  let isSending: Bool
  let toast: ToastCenter
  @Binding var scrollProxy: ScrollViewProxy?
  @Binding var isNearBottom: Bool
  @Binding var lastMessageId: UUID?
  var onSpeak: ((ChatMessage) -> Void)? = nil
  var speakingMessageId: UUID? = nil

  @Query private var messages: [ChatMessage]
  @Environment(\.modelContext) private var modelContext
  @Environment(\.undoManager) private var undoManager
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var scrollOffset: CGFloat = 0
  @State private var scrollUpdateTask: Task<Void, Never>?

  // Unified swipe edge: Always swipe from trailing edge for consistency
  private var swipeEdge: HorizontalEdge {
    .trailing
  }

  init(
    conversation: Conversation,
    isSending: Bool = false,
    toast: ToastCenter,
    scrollProxy: Binding<ScrollViewProxy?>,
    isNearBottom: Binding<Bool>,
    lastMessageId: Binding<UUID?>,
    onSpeak: ((ChatMessage) -> Void)? = nil,
    speakingMessageId: UUID? = nil
  ) {
    self.conversation = conversation
    self.isSending = isSending
    self.toast = toast
    _scrollProxy = scrollProxy
    _isNearBottom = isNearBottom
    _lastMessageId = lastMessageId
    self.onSpeak = onSpeak
    self.speakingMessageId = speakingMessageId
    let convoId = conversation.id
    let predicate = #Predicate<ChatMessage> { $0.conversation?.id == convoId }
    _messages = Query(filter: predicate, sort: \ChatMessage.createdAt)
  }

  var body: some View {
    ScrollViewReader { proxy in
      self.scrollContent(proxy: proxy)
    }
  }

  @ViewBuilder
  private func scrollContent(proxy: ScrollViewProxy) -> some View {
    let listContent = messageList()
      .padding(.vertical, Space.md)
      .padding(.horizontal, Space.md)
      .background(scrollOffsetReader)

    let baseScrollView = ScrollView(showsIndicators: false) {
      listContent
    }
    .coordinateSpace(name: "scroll")
    .contentShape(Rectangle())
    .scrollDismissesKeyboard(.interactively)
    .scrollBounceBehavior(.basedOnSize)

    baseScrollView
      .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: handleScrollOffsetChange)
      .overlay(emptyStateOverlay)
      // Use smooth animation for message count changes to prevent jank
      .animation(reduceMotion ? nil : AnimationUtilities.smooth, value: messages.count)
      .onAppear { handleAppear(proxy: proxy) }
      .onDisappear { handleDisappear() }
      .onChange(of: messages.count) { _, _ in handleMessageCountChange(proxy: proxy) }
      .onChange(of: messages.last?.id) { _, newId in handleLastMessageIdChange(newId) }
      .modifier(scrollThrottler(proxy: proxy))
      // Keep layout direction LTR for consistent bubble positioning
      // Text alignment within bubbles is handled by individual components
      .environment(\.layoutDirection, .leftToRight)
      // Ensure smooth scrolling during generation without blocking
      .scrollContentBackground(.hidden)
  }

  @ViewBuilder
  private func messageList() -> some View {
    // Unified layout: Always use leading alignment for consistent structure
    // Individual message rows handle their own alignment (user right, assistant left)
    LazyVStack(alignment: .leading, spacing: Space.md) {
      ForEach(messages) { m in
        messageRow(for: m)
      }
    }
  }

  @ViewBuilder
  private func messageRow(for message: ChatMessage) -> some View {
    let isLatest = message.id == messages.last?.id
    MessageRowView(
      message: message,
      isLatest: isLatest,
      isGeneratingLatest: isLatest && isSending,
      onRetry: {
        NotificationCenter.default.post(name: .retryAssistantMessage, object: message)
      },
      onSpeak: onSpeak,
      speakingMessageId: speakingMessageId
    )
    .id(message.id)
    .transition(.opacity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel(for: message))
    .accessibilityHint(L("swipe_left_for_actions"))
    .swipeActions(edge: swipeEdge) {
      swipeActions(for: message)
    }
  }

  @ViewBuilder
  private func swipeActions(for message: ChatMessage) -> some View {
    Button(L("copy")) {
      #if os(iOS)
        UIPasteboard.general.string = message.text
        HapticFeedback.selection()
      #endif
    }
    .tint(Brand.primary)

    if message.role == .assistant {
      Button(L("retry")) {
        NotificationCenter.default.post(name: .retryAssistantMessage, object: message)
        HapticFeedback.selection()
      }
      .tint(Brand.warning)
    } else if message.role == .user {
      Button(L("delete"), role: .destructive) {
        deleteMessage(message)
        HapticFeedback.notification(.warning)
      }
    }
  }

  private func deleteMessage(_ message: ChatMessage) {
    let deletedId = message.id
    let deletedText = message.text
    let deletedRole = message.role
    let convo = message.conversation
    modelContext.delete(message)
    try? modelContext.save()
    toast.show(L("message_deleted"), kind: .warning, actionTitle: L("undo"))
    undoManager?.registerUndo(
      withTarget: UndoReinserter(modelContext: modelContext)
    ) { target in
      if let convo = convo {
        let restored = ChatMessage(
          id: deletedId, createdAt: Date(), role: deletedRole,
          text: deletedText, conversation: convo)
        target.modelContext.insert(restored)
        try? target.modelContext.save()
      }
    }
  }

  private var scrollOffsetReader: some View {
    GeometryReader { geometry in
      Color.clear
        .preference(
          key: ScrollOffsetPreferenceKey.self,
          value: geometry.frame(in: .named("scroll")).minY
        )
    }
  }

  private func handleScrollOffsetChange(_ value: CGFloat) {
    scrollUpdateTask?.cancel()
    // Use async task to prevent blocking UI thread during scroll
    scrollUpdateTask = Task { @MainActor in
      // Throttle scroll updates to ~60Hz (16.67ms) for smooth performance
      try? await Task.sleep(nanoseconds: 16_666_666)
      guard !Task.isCancelled else { return }
      scrollOffset = value
      // Update isNearBottom state - user is near bottom if scroll offset is close to bottom
      isNearBottom = messages.isEmpty || value <= -50
    }
  }

  @ViewBuilder
  private var emptyStateOverlay: some View {
    if messages.isEmpty {
      VStack(spacing: Space.lg) {
        Image(systemName: "message.badge")
          .font(.system(size: 48, weight: .light))
          .foregroundStyle(Brand.textSecondary.opacity(0.6))
          .modifier(ConditionalSymbolEffect(reduceMotion: reduceMotion))

        VStack(spacing: Space.xs) {
          Text(L("ask_me_anything"))
            .font(TypeScale.headline)
            .foregroundStyle(Brand.textPrimary)
          Text(L("try_prompt"))
            .font(TypeScale.subhead)
            .foregroundStyle(Brand.textSecondary)
        }
      }
      .multilineTextAlignment(.center)
      .padding(Space.xl)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .allowsHitTesting(false)
      .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(L("new_chat_description"))
    }
  }

  private func handleAppear(proxy: ScrollViewProxy) {
    scrollProxy = proxy
    // Use async to ensure smooth initial scroll without blocking
    Task { @MainActor in
      if let last = messages.last {
        lastMessageId = last.id
        scrollToBottom(proxy: proxy, id: last.id, animated: false)
        isNearBottom = true
      }
    }
  }

  private func handleDisappear() {
    scrollUpdateTask?.cancel()
  }

  private func handleMessageCountChange(proxy: ScrollViewProxy) {
    if let last = messages.last {
      lastMessageId = last.id
      // CRITICAL: Always scroll to show new messages immediately when they're added
      // This ensures user message and assistant placeholder appear right away
      // Use async to prevent blocking UI during message updates
      Task { @MainActor in
        // During streaming, use smooth scroll; otherwise use quick scroll
        scrollToBottom(proxy: proxy, id: last.id, animated: true)
        // Update isNearBottom state - if we just added messages, user is at bottom
        if !isSending {
          isNearBottom = true
        }
      }
    }
  }

  private func handleLastMessageIdChange(_ newId: UUID?) {
    if let id = newId {
      lastMessageId = id
    }
  }

  private func scrollThrottler(proxy: ScrollViewProxy) -> StreamScrollThrottler {
    StreamScrollThrottler(
      messages: messages,
      isNearBottomBinding: $isNearBottom,
      scroll: { id in
        // Only auto-scroll if user is near bottom
        // This prevents interrupting user scrolling while allowing smooth follow during generation
        if isNearBottom {
          scrollToBottom(proxy: proxy, id: id)
        }
      }
    )
  }

  private func accessibilityLabel(for message: ChatMessage) -> String {
    switch message.role {
    case .user:
      return L("message_from_you")
    case .assistant:
      return L("message_from_assistant")
    case .system:
      return L("message_from_system")
    }
  }
}

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetPreferenceKey: PreferenceKey {
  nonisolated static var defaultValue: CGFloat { 0 }
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// Helper target for Undo registration
final class UndoReinserter: NSObject {
  let modelContext: ModelContext
  init(modelContext: ModelContext) { self.modelContext = modelContext }
}

@MainActor
extension ChatListView {
  /// Centralized scrolling behavior to keep streaming in sync and allow future tuning.
  /// Optimized for smooth 120Hz ProMotion scrolling with non-blocking async operations.
  private func scrollToBottom(proxy: ScrollViewProxy, id: UUID, animated: Bool = true) {
    // Function is already @MainActor, so no need for Task wrapper
    // Scroll operations are non-blocking by nature in SwiftUI
    if animated && !reduceMotion {
      // Use smooth animation for natural scrolling during streaming
      // AnimationUtilities.smooth provides optimal 120Hz performance
      withAnimation(AnimationUtilities.smooth) {
        proxy.scrollTo(id, anchor: .bottom)
      }
    } else {
      // Immediate scroll without animation for faster initial load or reduced motion
      proxy.scrollTo(id, anchor: .bottom)
    }
  }
}

// MARK: - Streaming Scroll Throttler

private struct StreamScrollThrottler: ViewModifier {
  let messages: [ChatMessage]
  @Binding var isNearBottomBinding: Bool
  let scroll: (UUID) -> Void
  @State private var lastScrollTime: Date = Date()
  @State private var scrollTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .onChange(of: messages.last?.text) { _, _ in
        guard let id = messages.last?.id else { return }
        // Only scroll if user is near bottom
        guard isNearBottomBinding else { return }
        // Throttle scroll updates during streaming to avoid excessive scrolling
        // Use async task to prevent blocking UI thread
        let now = Date()
        if now.timeIntervalSince(lastScrollTime) >= 0.05 {  // Max 20 updates per second (smooth for streaming)
          lastScrollTime = now
          // Cancel previous scroll task if still pending
          scrollTask?.cancel()
          // Execute scroll in async task to prevent UI blocking
          scrollTask = Task { @MainActor in
            scroll(id)
          }
        }
      }
      .onDisappear {
        scrollTask?.cancel()
      }
  }
}

// MARK: - Conditional Symbol Effect

private struct ConditionalSymbolEffect: ViewModifier {
  let reduceMotion: Bool
  
  func body(content: Content) -> some View {
    if reduceMotion {
      content
    } else {
      content.symbolEffect(.pulse, options: .repeating)
    }
  }
}
