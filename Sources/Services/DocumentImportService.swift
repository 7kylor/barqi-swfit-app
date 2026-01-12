import Foundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
final class DocumentImportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Import a document from a file URL (e.g., from share sheet or file picker)
    func importDocument(from sourceURL: URL) async throws -> Document {
        // Validate file type
        guard let fileType = supportedFileType(for: sourceURL) else {
            throw DocumentImportError.unsupportedFileType
        }

        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Generate document ID and destination URL
        let documentId = UUID()
        let destinationURL = try StoragePaths.documentURL(for: documentId)

        // Copy file to secure storage
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // Create document record
        let documentName = sourceURL.lastPathComponent
        let document = Document(
            id: documentId,
            name: documentName,
            filePath: destinationURL.path,
            fileType: fileType,
            sizeBytes: fileSize
        )

        // Save to SwiftData
        modelContext.insert(document)
        try modelContext.save()

        return document
    }

    /// Import multiple documents
    func importDocuments(from sourceURLs: [URL]) async throws -> [Document] {
        var documents: [Document] = []

        for url in sourceURLs {
            do {
                let document = try await importDocument(from: url)
                documents.append(document)
            } catch {
                Logger.log("Failed to import document \(url.lastPathComponent): \(error)", level: .error, category: Logger.system)
                // Continue with other documents
            }
        }

        return documents
    }

    /// Delete a document and its associated data
    func deleteDocument(_ document: Document) throws {
        // Remove file from storage
        let fileURL = URL(fileURLWithPath: document.filePath)
        try? FileManager.default.removeItem(at: fileURL)

        // SwiftData will cascade delete chunks and conversation associations
        modelContext.delete(document)
        try modelContext.save()
    }

    // MARK: - File Type Support

    private func supportedFileType(for url: URL) -> String? {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return "pdf"
        case "txt":
            return "txt"
        case "md", "markdown":
            return "md"
        case "docx":
            return "docx"
        case "rtf":
            return "rtf"
        default:
            return nil
        }
    }

    /// Get supported UTTypes for file picker
    static var supportedUTTypes: [UTType] {
        [
            .pdf,
            .text,
            .utf8PlainText,
            .plainText,
            .rtf,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!,
            UTType(filenameExtension: "docx")!
        ]
    }
}

// MARK: - Errors

enum DocumentImportError: LocalizedError {
    case unsupportedFileType
    case fileCopyFailed
    case invalidFileSize

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported file type. Only PDF, TXT, MD, DOCX, and RTF files are supported."
        case .fileCopyFailed:
            return "Failed to copy file to secure storage."
        case .invalidFileSize:
            return "File size is invalid or too large."
        }
    }
}