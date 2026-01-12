import Foundation
import SwiftData
import Observation

@MainActor
final class DocumentProcessingService {
    private let modelContext: ModelContext
    private let parserService: DocumentParserService
    private let chunkingService: TextChunkingService
    private let embeddingService: EmbeddingService
    private let vectorStoreService: VectorStoreService

    init(
        modelContext: ModelContext,
        parserService: DocumentParserService,
        chunkingService: TextChunkingService,
        embeddingService: EmbeddingService,
        vectorStoreService: VectorStoreService
    ) {
        self.modelContext = modelContext
        self.parserService = parserService
        self.chunkingService = chunkingService
        self.embeddingService = embeddingService
        self.vectorStoreService = vectorStoreService
    }

    // MARK: - Public Methods

    /// Process a document asynchronously (parse → chunk → embed → store)
    func processDocument(_ document: Document) async throws {
        // Update status to processing
        document.status = .processing
        try modelContext.save()

        do {
            // Step 1: Parse text from document
            let text = try parserService.parseText(from: document)

            // Step 2: Chunk the text
            let textChunks = chunkingService.chunkText(text)

            // Step 3: Create DocumentChunk records
            let documentChunks = try chunkingService.createDocumentChunks(
                for: document.id,
                from: textChunks,
                modelContext: modelContext
            )

            // Step 4: Generate embeddings and store in vector store
            try await generateAndStoreEmbeddings(for: documentChunks)

            // Step 5: Update document status
            document.status = .processed
            document.processedAt = Date()
            document.chunkCount = documentChunks.count
            try modelContext.save()

        } catch {
            // Update status to failed
            document.status = .failed
            try modelContext.save()
            throw error
        }
    }

    /// Process multiple documents sequentially
    func processDocuments(_ documents: [Document]) async throws {
        for document in documents {
            try await processDocument(document)
        }
    }

    /// Get processing status for a document
    func getProcessingStatus(for document: Document) -> DocumentProcessingStatus {
        DocumentProcessingStatus(
            document: document,
            isProcessing: document.status == .processing,
            isComplete: document.status == .processed,
            hasError: document.status == .failed
        )
    }

    // MARK: - Private Methods

    private func generateAndStoreEmbeddings(for chunks: [DocumentChunk]) async throws {
        // Process chunks in batches to avoid overwhelming the system
        let batchSize = 10

        for batchStart in stride(from: 0, to: chunks.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, chunks.count)
            let batch = Array(chunks[batchStart..<batchEnd])

            // Generate embeddings for batch
            let texts = batch.map { $0.text }
            let embeddings = try await embeddingService.generateEmbeddings(for: texts)

            // Store each chunk with its embedding
            for (index, chunk) in batch.enumerated() {
                let embedding = embeddings[index]
                try await vectorStoreService.storeChunk(chunk, embedding: embedding)
            }
        }
    }
}

// MARK: - Supporting Types

struct DocumentProcessingStatus {
    let document: Document
    let isProcessing: Bool
    let isComplete: Bool
    let hasError: Bool

    var progressText: String {
        switch document.status {
        case .imported:
            return "Ready to process"
        case .processing:
            return "Processing..."
        case .processed:
            return "Ready for RAG"
        case .failed:
            return "Processing failed"
        }
    }
}