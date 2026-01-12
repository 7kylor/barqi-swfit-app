import SwiftData
import SwiftUI

struct ConversationsList: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
  let selectedConversationId: UUID?
  let onSelect: (Conversation) -> Void
  
  private var layoutDirection: LayoutDirection {
    RTLUtilities.layoutDirection
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: Space.lg, pinnedViews: []) {
        // Header
        VStack(alignment: .leading, spacing: Space.xs) {
          Text(L("recent_chats"))
            .font(TypeScale.headline)
            .foregroundStyle(Brand.textSecondary)
            .padding(.horizontal, Space.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.lg)
        
        // List
        GlassCard {
          LazyVStack(spacing: 0) {
            ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
              Button {
                onSelect(conversation)
                dismiss()
              } label: {
                HStack(alignment: .center, spacing: Space.sm) {
                  VStack(alignment: .leading, spacing: Space.xs) {
                    Text(conversation.title)
                      .font(TypeScale.body)
                      .fontWeight(conversation.id == selectedConversationId ? .semibold : .regular)
                      .foregroundStyle(Brand.textPrimary)
                      .lineLimit(1)
                      .multilineTextAlignment(.leading)
                    
                    Text(AppFormatters.westernDateString(conversation.createdAt))
                      .font(TypeScale.caption)
                      .foregroundStyle(Brand.textSecondary)
                      .multilineTextAlignment(.leading)
                      .monospacedDigit()
                  }
                  
                  Spacer(minLength: Space.md)
                  
                  if conversation.id == selectedConversationId {
                    Image(systemName: "checkmark.circle.fill")
                      .font(.body)
                      .foregroundStyle(Brand.primary)
                  } else {
                    Image(systemName: "chevron.right")
                      .font(.caption)
                      .foregroundStyle(Brand.textSecondary.opacity(0.5))
                      .flipsForRightToLeftLayoutDirection(true)
                  }
                }
                .padding(.vertical, Space.md)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .contextMenu {
                Button(role: .destructive) {
                  delete(conversation)
                } label: {
                  Label(L("delete"), systemImage: "trash")
                }
              }
              
              if index < conversations.count - 1 {
                Divider()
              }
            }
          }
        }
      }
      .padding(.horizontal, Space.lg)
      .padding(.bottom, Space.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(Brand.surface)
    .navigationTitle(L("conversations"))
    .environment(\.layoutDirection, layoutDirection)
  }

  private func delete(_ conversation: Conversation) {
    modelContext.delete(conversation)
    try? modelContext.save()
  }
}
