import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - Navigation Destination

/// Navigation destinations for the app
enum SidebarDestination: Hashable, Identifiable {
    case chat
    case models
    case conversations
    case settings
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .chat: return L("chat")
        case .models: return L("models")
        case .conversations: return L("conversations")
        case .settings: return L("settings")
        }
    }
    
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .models: return "brain.head.profile"
        case .conversations: return "message"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Adaptive Navigation Container

/// Container that provides appropriate navigation based on device type
/// - iPhone: NavigationStack (current behavior)
/// - iPad/Mac: NavigationSplitView with sidebar
struct AdaptiveNavigationContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedDestination: SidebarDestination? = .chat
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    let content: (Binding<SidebarDestination?>) -> Content
    
    init(@ViewBuilder content: @escaping (Binding<SidebarDestination?>) -> Content) {
        self.content = content
    }
    
    var body: some View {
        if shouldUseSplitView {
            splitViewNavigation
        } else {
            stackNavigation
        }
    }
    
    private var shouldUseSplitView: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    // MARK: - Split View Navigation (iPad/Mac)
    
    private var splitViewNavigation: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedDestination)
                .navigationSplitViewColumnWidth(min: 200, ideal: Layout.sidebarWidth, max: 350)
        } detail: {
            content($selectedDestination)
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Stack Navigation (iPhone)
    
    private var stackNavigation: some View {
        content($selectedDestination)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selection: SidebarDestination?
    @Environment(AppModel.self) private var app
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    
    var body: some View {
        List(selection: $selection) {
            // Main Navigation
            Section {
                NavigationLink(value: SidebarDestination.chat) {
                    Label(SidebarDestination.chat.title, systemImage: SidebarDestination.chat.icon)
                }
                
                NavigationLink(value: SidebarDestination.models) {
                    Label(SidebarDestination.models.title, systemImage: SidebarDestination.models.icon)
                }
                
                NavigationLink(value: SidebarDestination.conversations) {
                    Label(SidebarDestination.conversations.title, systemImage: SidebarDestination.conversations.icon)
                }
            } header: {
                Text(L("navigation"))
            }
            
            // Recent Conversations
            if !conversations.isEmpty {
                Section {
                    ForEach(conversations.prefix(5)) { conversation in
                        ConversationSidebarRow(conversation: conversation)
                    }
                    
                    if conversations.count > 5 {
                        NavigationLink(value: SidebarDestination.conversations) {
                            Label(L("view_all"), systemImage: "ellipsis")
                                .foregroundStyle(Brand.textSecondary)
                        }
                    }
                } header: {
                    Text(L("recent"))
                }
            }
            
            // Settings at bottom
            Section {
                NavigationLink(value: SidebarDestination.settings) {
                    Label(SidebarDestination.settings.title, systemImage: SidebarDestination.settings.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(L("app_name"))
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // New chat action
                    NotificationCenter.default.post(name: .createNewConversation, object: nil)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help(L("create_new_conversation"))
            }
        }
        #endif
    }
}

// MARK: - Conversation Sidebar Row

private struct ConversationSidebarRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(Brand.primary.opacity(0.2))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(TypeScale.subhead)
                    .lineLimit(1)
                
                if let lastMessage = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt }).last {
                    Text(lastMessage.text)
                        .font(TypeScale.caption)
                        .foregroundStyle(Brand.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewConversation = Notification.Name("createNewConversation")
}

// MARK: - iPad Specific Modifiers

extension View {
    /// Apply iPad-optimized reading width
    @ViewBuilder
    func iPadReadableWidth() -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.frame(maxWidth: Layout.maxReadableWidth)
        } else {
            self
        }
        #else
        self.frame(maxWidth: Layout.maxReadableWidth)
        #endif
    }
    
    /// Center content on wider screens
    @ViewBuilder
    func centeredOnWideScreens() -> some View {
        GeometryReader { geometry in
            if geometry.size.width > Layout.maxReadableWidth {
                HStack {
                    Spacer()
                    self.frame(maxWidth: Layout.maxReadableWidth)
                    Spacer()
                }
            } else {
                self
            }
        }
    }
}

// MARK: - Keyboard Shortcuts Container

struct KeyboardShortcutsContainer<Content: View>: View {
    let onNewChat: () -> Void
    let onToggleSidebar: () -> Void
    let content: Content
    
    init(
        onNewChat: @escaping () -> Void,
        onToggleSidebar: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.onNewChat = onNewChat
        self.onToggleSidebar = onToggleSidebar
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                // Hidden buttons for keyboard shortcuts
                Group {
                    Button(action: onNewChat) {
                        EmptyView()
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .opacity(0)
                    
                    #if os(macOS)
                    Button(action: onToggleSidebar) {
                        EmptyView()
                    }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                    .opacity(0)
                    #endif
                }
            )
    }
}

// MARK: - Touch Bar Support (macOS)

#if os(macOS)
extension View {
    func withTouchBarSupport() -> some View {
        self.touchBar {
            Button {
                NotificationCenter.default.post(name: .createNewConversation, object: nil)
            } label: {
                Label(L("new_chat"), systemImage: "plus")
            }
        }
    }
}
#endif
