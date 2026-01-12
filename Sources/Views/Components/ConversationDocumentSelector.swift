import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ConversationDocumentSelector: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.layoutDirection) private var layoutDirection
  @Query private var documents: [Document]
  let conversation: Conversation

  @State private var selectedDocumentIds: Set<UUID> = []
  @State private var showingDocumentPicker = false
  @State private var isImporting = false

  private var isRTL: Bool {
    RTLUtilities.isRTL
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        if selectedDocuments.isEmpty {
          emptyStateView
        } else {
          selectedDocumentsView
        }
      }
      .navigationTitle(L("select_documents"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: isRTL ? .topBarTrailing : .topBarLeading) {
            addButton
          }
          ToolbarItem(placement: isRTL ? .topBarLeading : .topBarTrailing) {
            doneButton
          }
        }
      #else
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            addButton
          }
          ToolbarItem(placement: .confirmationAction) {
            doneButton
          }
        }
      #endif
    }
    .environment(\.layoutDirection, RTLUtilities.layoutDirection)
    .onAppear {
      loadSelectedDocuments()
    }
    #if os(iOS)
      .sheet(isPresented: $showingDocumentPicker) {
        DocumentPicker { urls in
          Task {
            await importDocuments(from: urls)
          }
        }
      }
    #else
      .fileImporter(
        isPresented: $showingDocumentPicker,
        allowedContentTypes: DocumentImportService.supportedUTTypes,
        allowsMultipleSelection: true
      ) { result in
        switch result {
        case .success(let urls):
          Task {
            await importDocuments(from: urls)
          }
        case .failure(let error):
          Logger.log("File import failed: \(error)", level: .error, category: Logger.system)
        }
      }
    #endif
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L("conversation_document_selector"))
  }

  private var addButton: some View {
    Button {
      let animation = reduceMotion ? nil : Animation.snappy(duration: 0.2)
      withAnimation(animation) {
        showingDocumentPicker = true
      }
    } label: {
      Image(systemName: "plus")
        .foregroundStyle(Brand.primary)
        .font(.system(size: 16, weight: .semibold))
        .frame(width: 32, height: 32)
    }
    .accessibilityLabel(L("add_document"))
    .accessibilityHint(L("add_document_to_conversation"))
  }

  private var doneButton: some View {
    Button {
      let animation = reduceMotion ? nil : Animation.snappy(duration: 0.2)
      withAnimation(animation) {
        dismiss()
      }
    } label: {
      Text(L("done"))
        .font(TypeScale.headline)
        .foregroundStyle(Brand.primary)
    }
    .accessibilityLabel(L("done"))
    .accessibilityHint(L("close_document_selector"))
  }

  private var emptyStateView: some View {
    VStack(spacing: Space.xl) {
      Spacer()

      VStack(spacing: Space.lg) {
        Image(systemName: "doc.text.magnifyingglass")
          .font(.system(size: 56, weight: .light))
          .foregroundStyle(Brand.primary.opacity(0.7))
          .accessibilityHidden(true)

        VStack(spacing: Space.sm) {
          Text(L("no_documents_selected"))
            .font(TypeScale.headline)
            .foregroundStyle(Brand.textPrimary)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
            .environment(\.layoutDirection, RTLUtilities.layoutDirection)

          Text(L("add_documents_rag_description"))
            .font(TypeScale.body)
            .foregroundStyle(Brand.textSecondary)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
            .padding(.horizontal, Space.xl)
            .environment(\.layoutDirection, RTLUtilities.layoutDirection)
        }

        Button {
          let animation = reduceMotion ? nil : Animation.snappy(duration: 0.2)
          withAnimation(animation) {
            showingDocumentPicker = true
          }
        } label: {
          HStack(spacing: Space.sm) {
            Image(systemName: "plus")
              .font(.system(size: 14, weight: .semibold))
            Text(L("add_document"))
              .font(TypeScale.headline)
          }
          .foregroundStyle(Brand.primary)
          .padding(.horizontal, Space.xl)
          .padding(.vertical, Space.md)
        }
        .liquidGlassCapsule(tintColor: Brand.primary.opacity(0.1))
        .accessibilityLabel(L("add_document"))
        .accessibilityHint(L("add_document_to_conversation"))
      }

      Spacer()
    }
    .padding(.horizontal, Space.lg)
    .padding(.vertical, Space.xl)
    .transition(.opacity.combined(with: .scale(scale: 0.95)))
  }

  private var selectedDocumentsView: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: Space.sm) {
        Image(systemName: "doc.text.fill")
          .foregroundStyle(Brand.primary)
          .font(.system(size: 14, weight: .medium))

        Text(L("active_documents_count", String(selectedDocuments.count)))
          .font(TypeScale.subhead)
          .foregroundStyle(Brand.textPrimary)

        Spacer()
      }
      .padding(.horizontal, Space.lg)
      .padding(.top, Space.lg)
      .padding(.bottom, Space.md)

      // Documents list
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: Space.sm) {
          ForEach(selectedDocuments.sorted(by: { $0.createdAt > $1.createdAt })) { document in
            MinimalDocumentRow(document: document) {
              let animation =
                reduceMotion ? nil : Animation.spring(response: 0.25, dampingFraction: 0.8)
              withAnimation(animation) {
                removeDocument(document)
              }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
          }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
      }
    }
    .transition(.opacity.combined(with: .scale(scale: 0.98)))
  }

  private var selectedDocuments: [Document] {
    documents.filter { selectedDocumentIds.contains($0.id) }
  }

  private func loadSelectedDocuments() {
    do {
      let conversationDocuments = try appModel.ragService.getConversationDocuments(
        for: conversation)
      selectedDocumentIds = Set(conversationDocuments.map { $0.documentId })
    } catch {
      Logger.log(
        "Failed to load conversation documents: \(error)", level: .error, category: Logger.system)
    }
  }

  private func addDocument(_ document: Document) {
    do {
      try appModel.ragService.addDocumentToConversation(document, conversation: conversation)
      selectedDocumentIds.insert(document.id)
    } catch {
      Logger.log(
        "Failed to add document to conversation: \(error)", level: .error, category: Logger.system)
    }
  }

  private func removeDocument(_ document: Document) {
    do {
      try appModel.ragService.removeDocumentFromConversation(document, conversation: conversation)
      selectedDocumentIds.remove(document.id)
    } catch {
      Logger.log(
        "Failed to remove document from conversation: \(error)", level: .error,
        category: Logger.system)
    }
  }

  private func importDocuments(from urls: [URL]) async {
    for url in urls {
      do {
        Logger.log(
          "Importing document: \(url.lastPathComponent)", level: .info, category: Logger.system)
        let document = try await appModel.documentImportService.importDocument(from: url)

        // Automatically add to current conversation
        try appModel.ragService.addDocumentToConversation(document, conversation: conversation)
        selectedDocumentIds.insert(document.id)

        // Process document in background
        Task {
          do {
            Logger.log(
              "Processing document: \(document.name)", level: .info, category: Logger.system)
            try await appModel.documentProcessingService.processDocument(document)
            Logger.log(
              "Document processed successfully: \(document.name)", level: .info,
              category: Logger.system)
          } catch {
            Logger.log(
              "Failed to process document \(document.name): \(error)", level: .error,
              category: Logger.system)
          }
        }
      } catch {
        Logger.log(
          "Failed to import document \(url.lastPathComponent): \(error)", level: .error,
          category: Logger.system)
      }
    }

    showingDocumentPicker = false
  }
}

struct MinimalDocumentRow: View {
  let document: Document
  let onRemove: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var isRTL: Bool {
    RTLUtilities.isRTL
  }

  var body: some View {
    HStack(spacing: Space.md) {
      // Document icon
      ZStack {
        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
          .fill(documentIconColor.opacity(0.15))
          .frame(width: 40, height: 40)

        Image(systemName: documentIconName)
          .foregroundStyle(documentIconColor)
          .font(.system(size: 16, weight: .medium))
      }
      .accessibilityHidden(true)

      // Document info
      VStack(alignment: isRTL ? .trailing : .leading, spacing: Space.xs) {
        Text(document.name)
          .font(TypeScale.body)
          .foregroundStyle(Brand.textPrimary)
          .lineLimit(2)
          .multilineTextAlignment(isRTL ? .trailing : .leading)
          .environment(\.layoutDirection, RTLUtilities.layoutDirection)

        HStack(spacing: Space.sm) {
          DocumentStatusBadge(status: document.status)

          Text(document.createdAt, style: .date)
            .font(TypeScale.caption)
            .foregroundStyle(Brand.textSecondary)
        }
      }

      Spacer(minLength: Space.sm)

      // Remove button
      Button {
        let animation = reduceMotion ? nil : Animation.snappy(duration: 0.2)
        withAnimation(animation) {
          onRemove()
        }
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Brand.textSecondary.opacity(0.6))
          .font(.system(size: 20))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L("remove_document"))
      .accessibilityHint(L("remove_document_from_conversation"))
    }
    .padding(Space.md)
    .liquidGlass(cornerRadius: Radius.md, tintColor: Brand.surface.opacity(0.2))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(L("document_item", document.name))
    .accessibilityHint(L("document_status", document.status.rawValue))
  }

  private var documentIconName: String {
    switch document.fileType {
    case "pdf": return "doc.richtext"
    case "docx": return "doc.richtext"
    case "txt": return "doc.plaintext"
    case "md": return "doc.plaintext"
    case "rtf": return "doc.richtext"
    default: return "doc"
    }
  }

  private var documentIconColor: Color {
    switch document.fileType {
    case "pdf": return .red
    case "docx": return .blue
    case "txt", "md": return .green
    case "rtf": return .orange
    default: return .gray
    }
  }
}

// MARK: - Preview

#Preview {
  // Note: Full preview requires AppModel context. This is a simplified preview.
  Text("ConversationDocumentSelector Preview")
    .padding()
    .liquidGlass()
}
