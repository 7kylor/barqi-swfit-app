import Foundation
import SwiftData

@MainActor
final class RAGService {
    private let modelContext: ModelContext
    private let embeddingService: EmbeddingService
    private let vectorStoreService: VectorStoreService

    init(
        modelContext: ModelContext,
        embeddingService: EmbeddingService,
        vectorStoreService: VectorStoreService
    ) {
        self.modelContext = modelContext
        self.embeddingService = embeddingService
        self.vectorStoreService = vectorStoreService
    }

    // MARK: - Public Methods

    /// Retrieve relevant context for a user query within a conversation
    func retrieveContext(
        for query: String,
        conversation: Conversation,
        topK: Int = 5
    ) async throws -> [RetrievedChunk] {
        // Get documents associated with this conversation
        let conversationDocuments = try getConversationDocuments(for: conversation)
        guard !conversationDocuments.isEmpty else {
            Logger.log("No documents associated with conversation \(conversation.id)", level: .debug, category: Logger.chat)
            return []
        }

        Logger.log("Found \(conversationDocuments.count) documents associated with conversation \(conversation.id)", level: .debug, category: Logger.chat)

        // Expand query for better retrieval
        let expandedQueries = expandQuery(query)

        // Generate embeddings for all query variations
        var allEmbeddings: [[Float]] = []
        for expandedQuery in expandedQueries {
            let embedding = try await embeddingService.generateEmbedding(for: expandedQuery)
            allEmbeddings.append(embedding)
        }

        // Search with multiple query embeddings
        var allSearchResults: [VectorSearchResult] = []
        for embedding in allEmbeddings {
            let results = try await vectorStoreService.searchSimilar(
                queryEmbedding: embedding,
                topK: topK * 3 // Get more results for diversity
            )
            allSearchResults.append(contentsOf: results)
        }

        // Remove duplicates and filter by conversation documents
        let conversationDocumentIds = Set(conversationDocuments.map { $0.documentId })
        let uniqueResults = Dictionary(grouping: allSearchResults) { result in
            "\(result.chunkId)-\(result.documentId)"
        }.compactMap { _, results in
            results.first
        }.filter { result in
            conversationDocumentIds.contains(result.documentId)
        }

        // Re-rank results by combining scores and diversity
        let reRankedResults = reRankResults(uniqueResults, originalQuery: query, expandedQueries: expandedQueries)

        // Take top K results with diversity consideration
        let topResults = selectDiverseResults(reRankedResults, maxResults: topK)

        let retrievedChunks = try await convertToRetrievedChunks(searchResults: topResults)
        Logger.log("Retrieved \(retrievedChunks.count) RAG chunks for query: '\(query)'", level: .debug, category: Logger.chat)

        return retrievedChunks
    }

    /// Add a document to a conversation for RAG
    func addDocumentToConversation(_ document: Document, conversation: Conversation) throws {
        let conversationDocument = ConversationDocument(
            conversationId: conversation.id,
            documentId: document.id
        )
        modelContext.insert(conversationDocument)
        try modelContext.save()
    }

    /// Remove a document from a conversation
    func removeDocumentFromConversation(_ document: Document, conversation: Conversation) throws {
        let conversationId = conversation.id
        let documentId = document.id
        let descriptor = FetchDescriptor<ConversationDocument>(
            predicate: #Predicate<ConversationDocument> { cd in
                cd.conversationId == conversationId && cd.documentId == documentId
            }
        )

        if let conversationDocument = try modelContext.fetch(descriptor).first {
            modelContext.delete(conversationDocument)
            try modelContext.save()
        }
    }

    /// Get all documents associated with a conversation
    func getConversationDocuments(for conversation: Conversation) throws -> [ConversationDocument] {
        let conversationId = conversation.id
        let descriptor = FetchDescriptor<ConversationDocument>(
            predicate: #Predicate<ConversationDocument> { cd in
                cd.conversationId == conversationId
            }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Augment a user message with retrieved context
    func augmentPrompt(userMessage: String, context: [RetrievedChunk]) -> String {
        guard !context.isEmpty else {
            return userMessage
        }

        // Format context chunks
        let contextText = context.map { chunk in
            "From document '\(chunk.document.name)':\n\(chunk.chunk.text)"
        }.joined(separator: "\n\n")

        // Create augmented prompt
        let augmentedPrompt = """
        Based on the following documents:

        \(contextText)

        User query: \(userMessage)

        Please provide a helpful response based on the above documents when relevant.
        """

        return augmentedPrompt
    }

    // MARK: - Private Methods

    private func convertToRetrievedChunks(searchResults: [VectorSearchResult]) async throws -> [RetrievedChunk] {
        var retrievedChunks: [RetrievedChunk] = []

        for result in searchResults {
            let chunkId = result.chunkId
            let documentId = result.documentId

            // Fetch the document chunk
            let chunkDescriptor = FetchDescriptor<DocumentChunk>(
                predicate: #Predicate<DocumentChunk> { chunk in
                    chunk.id == chunkId
                }
            )

            guard let chunk = try modelContext.fetch(chunkDescriptor).first else {
                continue
            }

            // Fetch the document
            let documentDescriptor = FetchDescriptor<Document>(
                predicate: #Predicate<Document> { doc in
                    doc.id == documentId
                }
            )

            guard let document = try modelContext.fetch(documentDescriptor).first else {
                continue
            }

            let retrievedChunk = RetrievedChunk(
                chunk: chunk,
                document: document,
                similarityScore: result.similarityScore
            )

            retrievedChunks.append(retrievedChunk)
        }

        return retrievedChunks
    }

    // MARK: - Enhanced Retrieval Methods

    /// Expand query to find more relevant content
    private func expandQuery(_ query: String) -> [String] {
        var expanded = [query]

        // Add lowercase version for better matching
        if query != query.lowercased() {
            expanded.append(query.lowercased())
        }

        // Extract key terms and create focused queries
        let words = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 } // Focus on meaningful words
            .prefix(3) // Limit to top 3 key terms

        if !words.isEmpty {
            // Create query focused on key terms
            let keyTermsQuery = words.joined(separator: " ")
            if keyTermsQuery != query && keyTermsQuery.count > 5 {
                expanded.append(keyTermsQuery)
            }

            // Create broader context query
            let broadQuery = words.map { "\"\($0)\"" }.joined(separator: " OR ")
            expanded.append(broadQuery)
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return expanded.filter { seen.insert($0).inserted }
    }

    /// Re-rank search results for better relevance
    private func reRankResults(_ results: [VectorSearchResult], originalQuery: String, expandedQueries: [String]) -> [VectorSearchResult] {
        let originalWords = Set(originalQuery.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })

        return results.map { result in
            var score = result.similarityScore

            // Boost score if result contains original query terms
            let text = result.text
            let resultWords = Set(text.lowercased().components(separatedBy: .whitespacesAndNewlines))
            let matchingWords = originalWords.intersection(resultWords)
            let matchRatio = Double(matchingWords.count) / Double(originalWords.count)

            // Boost score for exact term matches
            score += Float(matchRatio * 0.3)

            // Boost score for phrase matches
            if text.lowercased().contains(originalQuery.lowercased()) {
                score += 0.2
            }

            return VectorSearchResult(
                chunkId: result.chunkId,
                documentId: result.documentId,
                text: result.text,
                similarityScore: score
            )
        }.sorted { $0.similarityScore > $1.similarityScore }
    }

    /// Select diverse results to avoid redundancy while maintaining relevance
    private func selectDiverseResults(_ results: [VectorSearchResult], maxResults: Int) -> [VectorSearchResult] {
        guard results.count > maxResults else { return results }

        var selected: [VectorSearchResult] = []
        var usedDocuments = Set<UUID>()

        // First, take the top result
        if let first = results.first {
            selected.append(first)
            usedDocuments.insert(first.documentId)
        }

        // Then select diverse results from different documents when possible
        for result in results.dropFirst() {
            if selected.count >= maxResults { break }

            // Prefer results from documents we haven't used yet
            if !usedDocuments.contains(result.documentId) {
                selected.append(result)
                usedDocuments.insert(result.documentId)
            } else if result.similarityScore > 0.7 { // High relevance threshold for same document
                selected.append(result)
            }
        }

        // Fill remaining slots with highest scoring unused results
        for result in results {
            if selected.count >= maxResults { break }
            if !selected.contains(where: { $0.chunkId == result.chunkId }) {
                selected.append(result)
            }
        }

        return selected
    }

}