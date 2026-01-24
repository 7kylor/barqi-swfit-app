import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

// MARK: - Platform-Optimized Sidebar

/// Enhanced sidebar component optimized for macOS and iPadOS
/// Uses liquid glass design system with platform-specific styling
struct PlatformSidebar: View {
  @Binding var selectedItem: SidebarItem?
  @Binding var activeConversation: Conversation?
  @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
  @Environment(AppModel.self) private var app

  var body: some View {
    List(selection: $selectedItem) {
      // New Chat Button - Always visible at top for macOS and iPadOS
      Section {
        Button(action: {
          // Create new conversation
          let newConversation = app.createConversation()
          activeConversation = newConversation
          selectedItem = .chat
        }) {
          HStack(spacing: Space.md) {
            ZStack {
              Circle()
                .fill(Brand.primary.opacity(0.15))
                .frame(width: 32, height: 32)

              Image(systemName: "plus")
                .font(TypeScale.headline)
                .foregroundStyle(Brand.primary)
            }

            Text(L("new_chat"))
              .font(TypeScale.subhead)
              .fontWeight(.semibold)
              .foregroundStyle(Brand.primary)
          }
          .padding(.vertical, Space.sm)
          .padding(.horizontal, Space.md)
          .background(
            RoundedRectangle(cornerRadius: Radius.sm)
              .fill(Color.clear)
          )
          .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .adaptiveInteraction()
      }

      // Main Navigation Section
      Section {
        ForEach(SidebarItem.mainItems) { item in
          SidebarNavigationRow(
            item: item,
            isSelected: selectedItem == item
          )
          .tag(item)
        }
      } header: {
        SidebarSectionHeader(title: L("navigation"))
      }

      // Settings Section (at bottom)
      Section {
        SidebarNavigationRow(
          item: SidebarItem.settingsItem,
          isSelected: selectedItem == SidebarItem.settingsItem
        )
        .tag(SidebarItem.settingsItem)
      }

      // Recent Conversations Section
      if !conversations.isEmpty {
        Section {
          ForEach(conversations.prefix(10)) { conversation in
            SidebarConversationRow(
              conversation: conversation,
              isActive: activeConversation?.id == conversation.id,
              onSelect: {
                activeConversation = conversation
                selectedItem = .chat
              }
            )
          }

          if conversations.count > 10 {
            Button {
              selectedItem = .conversations
            } label: {
              SidebarMoreRow(count: conversations.count - 10)
            }
            .buttonStyle(.plain)
          }
        } header: {
          SidebarSectionHeader(title: L("recent"))
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle(L("app_name"))
    .sidebarPlatformStyling()
  }
}

// MARK: - Sidebar Navigation Row

struct SidebarNavigationRow: View {
  let item: SidebarItem
  let isSelected: Bool
  @State private var isHovered = false

  var body: some View {
    HStack(spacing: Space.md) {
      // Icon with liquid glass background
      ZStack {
        Circle()
          .fill(
            isSelected
              ? Brand.primary.opacity(0.15)
              : isHovered ? Brand.primary.opacity(0.08) : Brand.textSecondary.opacity(0.08)
          )
          .frame(width: 32, height: 32)

        Image(systemName: item.icon)
          .font(TypeScale.body)
          .foregroundStyle(isSelected ? Brand.primary : Brand.textSecondary)
      }

      Text(item.title)
        .font(TypeScale.subhead)
        .fontWeight(isSelected ? .semibold : .regular)
        .foregroundStyle(isSelected ? Brand.textPrimary : Brand.textSecondary)
    }
    .padding(.vertical, Space.sm)
    .padding(.horizontal, Space.sm)
    .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
    .onHover { hovering in
      withAnimation(AnimationUtilities.quick) {
        isHovered = hovering
      }
    }
    .adaptiveInteraction()
  }
}

// MARK: - Sidebar Conversation Row

struct SidebarConversationRow: View {
  let conversation: Conversation
  let isActive: Bool
  let onSelect: () -> Void
  @State private var isHovered = false

  private var previewText: String {
    if let lastMessage = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt }).last {
      return lastMessage.text
    }
    return ""
  }

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: Space.sm) {
        // Active indicator
        Circle()
          .fill(isActive ? Brand.primary : Brand.textSecondary.opacity(0.2))
          .frame(width: 6, height: 6)

        VStack(alignment: .leading, spacing: 2) {
          Text(conversation.title)
            .font(TypeScale.subhead)
            .fontWeight(isActive ? .semibold : .regular)
            .foregroundStyle(Brand.textPrimary)
            .lineLimit(1)

          if !previewText.isEmpty {
            Text(previewText)
              .font(TypeScale.caption)
              .foregroundStyle(Brand.textSecondary)
              .lineLimit(1)
          }
        }

        Spacer()
      }
      .padding(.vertical, Space.sm)
      .padding(.horizontal, Space.md)
      .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
      .background(
        RoundedRectangle(cornerRadius: Radius.sm)
          .fill(
            isActive
              ? Brand.primary.opacity(0.08) : isHovered ? Brand.primary.opacity(0.04) : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(AnimationUtilities.quick) {
        isHovered = hovering
      }
    }
    .adaptiveInteraction()
  }
}

// MARK: - Sidebar More Row

struct SidebarMoreRow: View {
  let count: Int

  var body: some View {
    HStack(spacing: Space.sm) {
      Image(systemName: "ellipsis")
        .font(TypeScale.caption)
        .foregroundStyle(Brand.textSecondary)

      Text(L("view_all") + " (\(count))")
        .font(TypeScale.caption)
        .foregroundStyle(Brand.textSecondary)
    }
    .padding(.vertical, Space.xs)
    .padding(.horizontal, Space.sm)
  }
}

// MARK: - Sidebar Section Header

struct SidebarSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(TypeScale.caption)
      .fontWeight(.semibold)
      .foregroundStyle(Brand.textSecondary.opacity(0.8))
      .textCase(.uppercase)
      .padding(.horizontal, Space.md)
      .padding(.top, Space.lg)
      .padding(.bottom, Space.sm)
  }
}

// MARK: - Platform-Specific Sidebar Styling

extension View {
  func sidebarPlatformStyling() -> some View {
    #if os(macOS)
      self
        .frame(minWidth: 200, idealWidth: 280, maxWidth: 350)
        .background(Brand.secondarySurface)
    #else
      self
        .frame(minWidth: 220, idealWidth: 320, maxWidth: 350)
        .background(Brand.surface)
    #endif
  }
}
