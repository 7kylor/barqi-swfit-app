import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(AppModel.self) private var app
  @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
  @State private var activeConversation: Conversation?
  @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
  @State private var selectedSidebarItem: SidebarItem? = .chat

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      PlatformSidebar(
        selectedItem: $selectedSidebarItem,
        activeConversation: $activeConversation
      )
    } detail: {
      switch selectedSidebarItem {
      case .chat, .conversations:
        if let selected = activeConversation {
          CouncilView(conversation: selected)
            .id(selected.id)
        } else {
          ContentUnavailableView(
            "Select a Session", systemImage: "building.columns",
            description: Text("Start a new Council session to begin."))
        }
      case .manifesto:
        ManifestoView()
      case .settings:
        Text("Settings View")
      case .none:
        Text("Select an item")
      }
    }
    .onAppear {
      if activeConversation == nil {
        activeConversation = conversations.first ?? app.createConversation()
      }
    }
  }
}

enum SidebarItem: String, Identifiable, CaseIterable {
  case chat
  case conversations
  case manifesto
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .chat: return "Council"
    case .conversations: return "History"
    case .manifesto: return "Manifesto"
    case .settings: return "Settings"
    }
  }

  var icon: String {
    switch self {
    case .chat: return "building.columns"
    case .conversations: return "clock"
    case .manifesto: return "quote.bubble"
    case .settings: return "gearshape"
    }
  }

  static var mainItems: [SidebarItem] {
    [.chat, .conversations, .manifesto]
  }

  static var settingsItem: SidebarItem {
    .settings
  }
}
