import Foundation
import Observation

// MARK: - WhisperKit Integration

#if canImport(WhisperKit)
  import WhisperKit
  private let whisperKitAvailable = true
#else
  private let whisperKitAvailable = false
#endif

/// Service for on-device speech-to-text transcription using WhisperKit
@MainActor
@Observable
final class VoiceTranscriptionService {

  // MARK: - Observable State

  private(set) var isLoading = false
  private(set) var isTranscribing = false
  private(set) var isModelLoaded = false
  private(set) var loadingProgress: Double = 0
  private(set) var currentTranscription: String = ""
  private(set) var streamingTranscription: String = ""
  private(set) var error: TranscriptionError?

  /// Callback for live transcription updates (called on MainActor)
  var onTranscriptionUpdate: ((String) -> Void)?

  /// Callback when Arabic speech is detected but model can't transcribe it (called on MainActor)
  /// This indicates the user needs a larger model for Arabic support
  var onArabicDetectedButNotSupported: (() -> Void)?

  /// Track if we've already notified about Arabic detection to avoid spam
  private var hasNotifiedAboutArabic = false

  // MARK: - Private Properties

  #if canImport(WhisperKit)
    private let transcriber = WhisperTranscriber()
    private var streamTranscriber: AudioStreamTranscriber?
  #endif
  private var modelName: String

  /// The model manager for quality selection
  private let modelManager: WhisperModelManager?

  // MARK: - Errors

  enum TranscriptionError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case transcriptionFailed(String)
    case audioFileNotFound
    case microphonePermissionDenied
    case cancelled
    case whisperKitNotAvailable

    var errorDescription: String? {
      switch self {
      case .modelNotLoaded:
        return L("voice_error_model_not_loaded")
      case .transcriptionFailed(let reason):
        return String(format: L("voice_error_transcription_failed"), reason)
      case .audioFileNotFound:
        return L("voice_error_audio_not_found")
      case .microphonePermissionDenied:
        return L("voice_error_mic_permission")
      case .cancelled:
        return L("voice_error_cancelled")
      case .whisperKitNotAvailable:
        return "WhisperKit is not installed. Please add the package dependency."
      }
    }
  }

  // MARK: - Initialization

  init(modelName: String = "tiny", modelManager: WhisperModelManager? = nil) {
    self.modelName = modelName
    self.modelManager = WhisperModelManager.shared  // Always use shared manager
  }

  /// Get the current model name from the manager or use default (fastest)
  private var currentModelName: String {
    let manager = WhisperModelManager.shared

    // If a model is already downloaded and active, use it
    if let activeModel = manager.activeModelName {
      return activeModel
    }

    // Otherwise, get the model name for the selected quality (defaults to fastest)
    return manager.getModelNameForTranscription()
  }

  // MARK: - Model Management

  func loadModel() async throws {
    #if canImport(WhisperKit)
      guard !isModelLoaded else { return }

      isLoading = true
      error = nil
      loadingProgress = 0

      let modelManager = WhisperModelManager.shared
      modelManager.startLoading()

      // First, ensure model manager has verified its state
      if !modelManager.isModelReady {
        Logger.log("Waiting for model manager to verify state...", category: Logger.voice)
        await modelManager.refreshModelState()
      }

      // Check if model needs to be downloaded
      var finalModelName = currentModelName
      var modelFolder: String? = nil

      if modelManager.isModelReady {
        // Model is ready to use
        finalModelName = modelManager.activeModelName ?? currentModelName
        modelFolder = modelManager.getModelFolder()

        // Check if the model has incomplete files (failed download)
        // SKIP this check for bundled models (they're always complete and read-only)
        let isBundledModel = modelFolder == WhisperModelManager.bundledModelFolder

        if !isBundledModel, let folder = modelFolder,
          !modelManager.hasCompleteTokenizer(atPath: folder)
        {
          Logger.log(
            "Model has incomplete files, deleting and re-downloading: \(finalModelName)",
            level: .info, category: Logger.voice
          )
          modelManager.deleteIncompleteModel(atPath: folder)
          modelFolder = nil
          // Fall through to download
        } else {
          Logger.log("Using ready Whisper model: \(finalModelName)", category: Logger.voice)
        }
      }

      // Check if we need to download (either no model or incomplete model)
      if modelFolder == nil {
        if case .notDownloaded = modelManager.downloadState {
          // Need to download
          Logger.log(
            "Model not downloaded, starting download: \(finalModelName)", category: Logger.voice)
          loadingProgress = 0.1
          modelManager.updateLoadingProgress(0.1)

          // Start download
          await modelManager.downloadModel()

          // Wait for download to complete with progress updates
          var lastProgress: Double = 0.1
          while case .downloading(let progress) = modelManager.downloadState {
            lastProgress = max(lastProgress, 0.1 + progress * 0.7)  // 0.1 to 0.8
            loadingProgress = lastProgress
            modelManager.updateLoadingProgress(lastProgress)
            try? await Task.sleep(for: .milliseconds(100))
          }

          // Check if download failed
          if case .failed(let errorMessage) = modelManager.downloadState {
            isLoading = false
            modelManager.finishLoading(success: false)
            let error = TranscriptionError.transcriptionFailed(
              "Model download failed: \(errorMessage)")
            self.error = error
            throw error
          }

          // Use the downloaded model
          if let downloadedModel = modelManager.activeModelName {
            finalModelName = downloadedModel
            modelFolder = modelManager.getModelFolder()
            Logger.log("Model downloaded successfully: \(downloadedModel)", category: Logger.voice)
          }
        } else if let activeModel = modelManager.activeModelName {
          // Use active model
          finalModelName = activeModel
          modelFolder = modelManager.getModelFolder()
        }
      }

      do {
        loadingProgress = 0.85
        modelManager.updateLoadingProgress(0.85)
        Logger.log(
          "Loading Whisper model: \(finalModelName), folder: \(modelFolder ?? "none")",
          category: Logger.voice)

        try await transcriber.loadModel(name: finalModelName, folder: modelFolder)

        // Verify model is actually loaded in the actor
        let actorModelLoaded = await transcriber.isModelLoaded
        guard actorModelLoaded else {
          throw TranscriptionError.modelNotLoaded
        }

        isModelLoaded = true
        loadingProgress = 1.0
        isLoading = false
        modelManager.finishLoading(success: true)

        Logger.log("Whisper model loaded successfully and verified", category: Logger.voice)
      } catch {
        isLoading = false
        modelManager.finishLoading(success: false)

        let errorMessage = error.localizedDescription
        Logger.log(
          "Failed to load Whisper model: \(errorMessage)",
          level: .error,
          category: Logger.voice
        )

        // Check if this is an incomplete download issue
        if errorMessage.contains("incomplete") || errorMessage.contains("tokenizer")
          || errorMessage.contains("missing")
        {
          // Delete the incomplete model and mark for re-download
          if let folder = modelFolder {
            Logger.log("Deleting incomplete model for re-download", category: Logger.voice)
            modelManager.deleteIncompleteModel(atPath: folder)
          }
        }

        // Try to recover by refreshing model state
        await modelManager.refreshModelState()

        self.error = .transcriptionFailed(errorMessage)
        throw error
      }
    #else
      throw TranscriptionError.whisperKitNotAvailable
    #endif
  }

  func unloadModel() {
    #if canImport(WhisperKit)
      Task {
        await transcriber.unloadModel()
        await MainActor.run {
          isModelLoaded = false
          loadingProgress = 0
          currentTranscription = ""
          Logger.log("Whisper model unloaded", category: Logger.voice)
        }
      }
    #else
      isModelLoaded = false
      loadingProgress = 0
      currentTranscription = ""
      Logger.log("Whisper model unloaded", category: Logger.voice)
    #endif
  }

  /// Verify model is actually loaded in the actor
  func verifyModelLoaded() async -> Bool {
    #if canImport(WhisperKit)
      return await transcriber.isModelLoaded
    #else
      return false
    #endif
  }

  // MARK: - Transcription

  @discardableResult
  func transcribe(audioPath: String) async throws -> String {
    #if canImport(WhisperKit)
      guard isModelLoaded else {
        throw TranscriptionError.modelNotLoaded
      }

      guard FileManager.default.fileExists(atPath: audioPath) else {
        throw TranscriptionError.audioFileNotFound
      }

      isTranscribing = true
      error = nil
      currentTranscription = ""

      do {
        Logger.log("Starting transcription for: \(audioPath)", category: Logger.voice)

        let result = try await transcriber.transcribe(audioPath: audioPath)

        let trimmedText = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        currentTranscription = trimmedText
        isTranscribing = false

        Logger.log("Transcription complete: \(trimmedText.prefix(50))...", category: Logger.voice)

        return trimmedText
      } catch {
        isTranscribing = false
        let wrappedError = TranscriptionError.transcriptionFailed(error.localizedDescription)
        self.error = wrappedError
        throw wrappedError
      }
    #else
      throw TranscriptionError.whisperKitNotAvailable
    #endif
  }

  @discardableResult
  func transcribe(audioURL: URL) async throws -> String {
    try await transcribe(audioPath: audioURL.path)
  }

  // MARK: - Streaming Transcription

  /// Start streaming transcription
  /// AudioStreamTranscriber handles microphone input internally
  func startStreamingTranscription() async throws {
    #if canImport(WhisperKit)
      // Ensure model is loaded - check actor's state directly (most reliable)
      let actorModelLoaded = await transcriber.isModelLoaded
      guard actorModelLoaded else {
        Logger.log(
          "startStreamingTranscription: Model not loaded in transcriber actor. Main actor state: \(isModelLoaded)",
          level: .error,
          category: Logger.voice
        )
        throw TranscriptionError.modelNotLoaded
      }

      // Get language preference from manager
      let languagePreference = WhisperModelManager.shared.getLanguageForTranscription()
      let languageDesc = languagePreference ?? "auto-detect"

      Logger.log(
        "startStreamingTranscription: Model verified, language=\(languageDesc), creating AudioStreamTranscriber...",
        category: Logger.voice)

      // Reset streaming transcription
      streamingTranscription = ""
      error = nil

      // Create AudioStreamTranscriber within the actor to avoid Sendable issues
      let streamTranscriber: AudioStreamTranscriber
      do {
        streamTranscriber = try await transcriber.createStreamTranscriber(
          language: languagePreference
        ) { [weak self] oldState, newState in
          // Extract text data before crossing actor boundaries
          var newText = newState.currentText
          let confirmedSegments = newState.confirmedSegments.map { $0.text }
          let textChanged = oldState.currentText != newState.currentText

          // Filter out placeholder and special token text
          // Whisper outputs these when it detects speech but can't transcribe it properly
          let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          let placeholders = [
            "waiting for speech...", "...", " ", "",
            // Arabic/foreign language placeholders that Whisper outputs when transcription fails
            "[speaking in arabic]", "(speaking in arabic)",
            "[speaking in foreign language]", "(speaking in foreign language)",
            "[speaking foreign language]", "(speaking foreign language)",
            "[foreign language]", "(foreign language)",
            "[speaking]", "(speaking)",
            "[music]", "(music)", "[applause]", "(applause)",
            "[laughter]", "(laughter)", "[silence]", "(silence)",
            "[inaudible]", "(inaudible)", "[unintelligible]", "(unintelligible)",
          ]

          // Check if the text is a placeholder or contains only placeholder content
          var isPlaceholder = placeholders.contains(trimmedText)
          var isArabicPlaceholder = false

          // Check specifically for Arabic detection placeholders
          let arabicPlaceholders = [
            "[speaking in arabic]", "(speaking in arabic)",
            "[speaking in foreign language]", "(speaking in foreign language)",
            "[speaking foreign language]", "(speaking foreign language)",
            "[foreign language]", "(foreign language)",
          ]
          if arabicPlaceholders.contains(trimmedText) {
            isArabicPlaceholder = true
            isPlaceholder = true
          }

          // Also check for partial matches with brackets/parentheses
          if !isPlaceholder {
            // Check for [Speaking in X] or (speaking in X) patterns
            let bracketPattern = "^[\\[\\(]\\s*speaking\\s*(in\\s+)?[^\\]\\)]*[\\]\\)]$"
            if let regex = try? NSRegularExpression(
              pattern: bracketPattern, options: .caseInsensitive)
            {
              let range = NSRange(trimmedText.startIndex..., in: trimmedText)
              if regex.firstMatch(in: trimmedText, options: [], range: range) != nil {
                isPlaceholder = true
                // Check if it mentions Arabic or foreign
                if trimmedText.contains("arabic") || trimmedText.contains("foreign") {
                  isArabicPlaceholder = true
                }
              }
            }
          }

          if isPlaceholder {
            newText = ""

            // Notify about Arabic detection if applicable
            if isArabicPlaceholder {
              Task { @MainActor [weak self] in
                guard let self = self, !self.hasNotifiedAboutArabic else { return }
                self.hasNotifiedAboutArabic = true
                Logger.log(
                  "Arabic speech detected but model cannot transcribe. User needs larger model.",
                  level: .info, category: Logger.voice
                )
                self.onArabicDetectedButNotSupported?()
              }
            }
          }

          // Remove any remaining special tokens that might have slipped through
          // These patterns match Whisper's special token format
          let specialTokenPattern = "<\\|[^|]+\\|>"
          if let regex = try? NSRegularExpression(pattern: specialTokenPattern, options: []) {
            let range = NSRange(newText.startIndex..., in: newText)
            newText = regex.stringByReplacingMatches(
              in: newText, options: [], range: range, withTemplate: "")
          }

          // Remove bracket/parenthesis annotations like [Speaking in Arabic]
          let annotationPattern = "[\\[\\(][^\\]\\)]*speaking[^\\]\\)]*[\\]\\)]"
          if let regex = try? NSRegularExpression(
            pattern: annotationPattern, options: .caseInsensitive)
          {
            let range = NSRange(newText.startIndex..., in: newText)
            newText = regex.stringByReplacingMatches(
              in: newText, options: [], range: range, withTemplate: "")
          }

          newText = newText.trimmingCharacters(in: .whitespacesAndNewlines)

          Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Update streaming transcription with current text (only if meaningful)
            if textChanged && !newText.isEmpty {
              self.streamingTranscription = newText
              // Call the callback to notify listeners directly
              let hasCallback = self.onTranscriptionUpdate != nil
              Logger.log(
                "Streaming transcription update: \(newText.prefix(50))... (callback=\(hasCallback ? "SET" : "NIL"))",
                category: Logger.voice
              )
              if hasCallback {
                self.onTranscriptionUpdate?(newText)
              }
            }

            // Process confirmed segments
            for segmentText in confirmedSegments {
              Logger.log(
                "Confirmed segment: \(segmentText)",
                category: Logger.voice
              )
            }
          }
        }
      } catch {
        Logger.log(
          "startStreamingTranscription: Failed to create AudioStreamTranscriber: \(error.localizedDescription)",
          level: .error,
          category: Logger.voice
        )
        throw error
      }

      self.streamTranscriber = streamTranscriber

      // Start streaming transcription (handles microphone input internally)
      Logger.log(
        "startStreamingTranscription: Starting stream transcription...", category: Logger.voice)
      try await streamTranscriber.startStreamTranscription()

      Logger.log("Started streaming transcription successfully", category: Logger.voice)
    #else
      throw TranscriptionError.whisperKitNotAvailable
    #endif
  }

  /// Stop streaming transcription
  func stopStreamingTranscription() async {
    #if canImport(WhisperKit)
      await streamTranscriber?.stopStreamTranscription()
      streamTranscriber = nil
      streamingTranscription = ""
      hasNotifiedAboutArabic = false  // Reset for next session
      Logger.log("Stopped streaming transcription", category: Logger.voice)
    #endif
  }

  /// Reset streaming transcription text
  func resetStreamingTranscription() {
    streamingTranscription = ""
  }
}

// MARK: - WhisperTranscriber (Thread-safe wrapper)

#if canImport(WhisperKit)
  /// Thread-safe wrapper around WhisperKit that handles transcription off the main actor
  /// Using actor for Swift 6.2 concurrency safety
  private actor WhisperTranscriber {
    // Note: WhisperKit is not Sendable, so we use nonisolated(unsafe) for third-party library
    nonisolated(unsafe) private var whisperKit: WhisperKit?

    var isModelLoaded: Bool {
      whisperKit != nil
    }

    func loadModel(name: String, folder: String?) async throws {
      // Enable prewarm and load to ensure tokenizer and all components are initialized
      // This is necessary for AudioStreamTranscriber to work properly

      let config: WhisperKitConfig
      if let folder = folder {
        // Use the saved model folder path - this is the most reliable method
        Logger.log(
          "loadModel: Using modelFolder=\(folder), prewarm=true, load=true", category: Logger.voice)
        config = WhisperKitConfig(
          modelFolder: folder,
          verbose: true,
          prewarm: true,
          load: true,
          download: false  // Don't download, use local folder
        )
      } else {
        // No folder saved, download the model
        Logger.log(
          "loadModel: No folder, using model=\(name), will download if needed",
          category: Logger.voice)
        config = WhisperKitConfig(
          model: name,
          verbose: true,
          prewarm: true,
          load: true
        )
      }

      Logger.log("loadModel: Initializing WhisperKit...", category: Logger.voice)
      let kit = try await WhisperKit(config)
      Logger.log(
        "loadModel: WhisperKit initialized. Checking components...", category: Logger.voice)

      // Log component availability
      // Note: These properties are non-optional in WhisperKit, so we check if kit itself is initialized
      Logger.log(
        "loadModel: WhisperKit initialized successfully with all components",
        category: Logger.voice)

      whisperKit = kit

      // Verify tokenizer is available after loading
      // If not available immediately, wait a bit for initialization
      if kit.tokenizer == nil {
        Logger.log(
          "loadModel: tokenizer not immediately available, waiting...", category: Logger.voice)
        for attempt in 1...20 {
          try? await Task.sleep(for: .milliseconds(100))
          if kit.tokenizer != nil {
            Logger.log(
              "loadModel: tokenizer available after \(attempt) attempts", category: Logger.voice)
            break
          }
        }
      }

      guard kit.tokenizer != nil else {
        Logger.log(
          "loadModel: tokenizer still not available after waiting. This usually means the model files are incomplete or corrupted.",
          level: .error, category: Logger.voice)
        // Try to provide more context
        Logger.log(
          "loadModel: Try deleting the model in Settings and re-downloading", level: .error,
          category: Logger.voice)
        throw VoiceTranscriptionService.TranscriptionError.modelNotLoaded
      }

      Logger.log("loadModel: Model loaded successfully with tokenizer", category: Logger.voice)
    }

    func unloadModel() {
      whisperKit = nil
    }

    func transcribe(audioPath: String) async throws -> String {
      guard let kit = whisperKit else {
        throw VoiceTranscriptionService.TranscriptionError.modelNotLoaded
      }

      // Call transcribe directly within actor isolation - no need to extract kit
      let results = try await kit.transcribe(audioPath: audioPath)
      let transcription = results.map { $0.text }.joined(separator: " ")

      guard !transcription.isEmpty else {
        throw VoiceTranscriptionService.TranscriptionError.transcriptionFailed(
          "No transcription result")
      }

      return transcription
    }

    /// Create AudioStreamTranscriber within actor isolation to avoid Sendable issues
    /// - Parameters:
    ///   - language: Language code for transcription (nil for auto-detect, "ar" for Arabic, "en" for English)
    ///   - onStateChange: Callback for transcription state changes
    func createStreamTranscriber(
      language: String?,
      onStateChange:
        @escaping @Sendable (AudioStreamTranscriber.State, AudioStreamTranscriber.State) -> Void
    ) async throws -> AudioStreamTranscriber {
      guard let kit = whisperKit else {
        Logger.log(
          "createStreamTranscriber: whisperKit is nil", level: .error, category: Logger.voice)
        throw VoiceTranscriptionService.TranscriptionError.modelNotLoaded
      }

      // Tokenizer should be available if prewarm was enabled during loadModel
      guard let finalTokenizer = kit.tokenizer else {
        Logger.log(
          "createStreamTranscriber: tokenizer is nil. Model may not have been prewarmed properly.",
          level: .error,
          category: Logger.voice
        )
        throw VoiceTranscriptionService.TranscriptionError.modelNotLoaded
      }

      let languageDesc = language ?? "auto-detect"
      Logger.log(
        "createStreamTranscriber: tokenizer available, language=\(languageDesc), creating AudioStreamTranscriber",
        category: Logger.voice)

      // Create AudioStreamTranscriber within actor isolation
      // For better Arabic support: use temperature > 0 to allow more varied outputs,
      // and lower noSpeechThreshold to be more sensitive to speech
      let streamTranscriber = AudioStreamTranscriber(
        audioEncoder: kit.audioEncoder,
        featureExtractor: kit.featureExtractor,
        segmentSeeker: kit.segmentSeeker,
        textDecoder: kit.textDecoder,
        tokenizer: finalTokenizer,
        audioProcessor: kit.audioProcessor,
        decodingOptions: DecodingOptions(
          task: .transcribe,  // Transcribe in original language (not translate to English)
          language: language,  // Language preference (nil = auto-detect, "ar" for Arabic)
          temperature: 0.2,  // Slightly higher temp for better multilingual output
          temperatureFallbackCount: 3,  // Allow fallback temperatures for difficult audio
          sampleLength: 224,  // Standard sample length for Whisper
          usePrefillPrompt: false,  // Don't use prefill for streaming
          usePrefillCache: false,  // Don't use cache for streaming
          skipSpecialTokens: true,  // Remove <|startoftranscript|> etc from output
          withoutTimestamps: true,  // Don't include timestamp tokens in text
          wordTimestamps: false,  // Disable for faster processing
          clipTimestamps: [],  // No clipping
          suppressBlank: true,  // Suppress blank outputs
          supressTokens: [],  // Empty array - [-1] causes out-of-bounds write crash (not a valid default)
          compressionRatioThreshold: 2.4,  // Standard compression threshold
          logProbThreshold: -1.0,  // Standard log prob threshold
          firstTokenLogProbThreshold: -1.5,  // Slightly relaxed for non-English
          noSpeechThreshold: 0.4  // Lower threshold for better Arabic detection
        ),
        requiredSegmentsForConfirmation: 2,  // Slightly more confirmation for accuracy
        useVAD: true,  // Voice Activity Detection for efficiency
        stateChangeCallback: onStateChange
      )

      Logger.log(
        "AudioStreamTranscriber created successfully with language: \(languageDesc)",
        category: Logger.voice)
      return streamTranscriber
    }
  }
#endif
