import AVFoundation
import Foundation
import Observation

/// Service for text-to-speech functionality using AVSpeechSynthesizer
@MainActor
@Observable
final class TextToSpeechService: NSObject {

  // MARK: - Observable State

  private(set) var isSpeaking = false
  private(set) var currentMessageId: UUID?
  private(set) var progress: Double = 0

  // MARK: - Private Properties

  private let synthesizer = AVSpeechSynthesizer()
  private var currentUtterance: AVSpeechUtterance?
  private var totalCharacters: Int = 0
  private var spokenCharacters: Int = 0

  // MARK: - Settings

  /// Speech rate (0.0 - 1.0, default 0.5)
  var rate: Float = AVSpeechUtteranceDefaultSpeechRate

  /// Volume (0.0 - 1.0, default 1.0)
  var volume: Float = 1.0

  // MARK: - Initialization

  override init() {
    super.init()
    synthesizer.delegate = self
    // Use the synthesizer's own audio session for better compatibility
    #if os(iOS)
      synthesizer.usesApplicationAudioSession = true
    #endif
  }

  // MARK: - Audio Session

  private func configureAudioSession() {
    #if os(iOS)
      do {
        let audioSession = AVAudioSession.sharedInstance()
        // Use playback category with defaultToSpeaker to ensure audio plays through speaker
        try audioSession.setCategory(
          .playback,
          mode: .spokenAudio,
          options: [.duckOthers, .defaultToSpeaker]
        )
        try audioSession.setActive(true)
        Logger.log("Audio session configured for TTS", category: Logger.voice)
      } catch {
        Logger.log(
          "Failed to configure audio session for TTS: \(error.localizedDescription)",
          level: .error,
          category: Logger.voice
        )
      }
    #endif
  }

  // MARK: - Public Methods

  /// Speak a single message
  /// - Parameters:
  ///   - text: The text to speak
  ///   - messageId: Optional message ID to track which message is being spoken
  ///   - language: The language of the text (for voice selection)
  func speak(text: String, messageId: UUID? = nil, language: DetectedLanguage? = nil) {
    stop()

    let cleanedText = cleanTextForSpeech(text)
    guard !cleanedText.isEmpty else {
      Logger.log("No text to speak after cleaning", level: .info, category: Logger.voice)
      return
    }

    currentMessageId = messageId
    totalCharacters = cleanedText.count
    spokenCharacters = 0
    progress = 0

    // Configure audio session before speaking
    configureAudioSession()

    let detectedLang = language ?? detectLanguage(text)
    let selectedVoice = selectVoice(for: detectedLang)

    let utterance = AVSpeechUtterance(string: cleanedText)
    utterance.rate = rate
    utterance.volume = volume
    utterance.pitchMultiplier = 1.0
    utterance.preUtteranceDelay = 0.1
    utterance.postUtteranceDelay = 0.1

    if let voice = selectedVoice {
      utterance.voice = voice
      Logger.log("Using voice: \(voice.identifier)", category: Logger.voice)
    } else {
      Logger.log("No voice available, using system default", level: .info, category: Logger.voice)
    }

    currentUtterance = utterance
    isSpeaking = true

    synthesizer.speak(utterance)

    Logger.log(
      "Started speaking text (\(cleanedText.count) chars, lang: \(detectedLang))",
      category: Logger.voice
    )
    Analytics.track(.ttsStarted)
  }

  /// Speak multiple messages in sequence
  /// - Parameter messages: Array of (text, messageId, language) tuples
  func speakConversation(_ messages: [(text: String, messageId: UUID, language: DetectedLanguage?)]) {
    stop()

    let utterances = messages.compactMap { message -> (AVSpeechUtterance, UUID)? in
      let cleanedText = cleanTextForSpeech(message.text)
      guard !cleanedText.isEmpty else { return nil }

      let utterance = AVSpeechUtterance(string: cleanedText)
      utterance.rate = rate
      utterance.volume = volume
      utterance.voice = selectVoice(for: message.language ?? detectLanguage(message.text))
      utterance.postUtteranceDelay = 0.5  // Pause between messages

      return (utterance, message.messageId)
    }

    guard !utterances.isEmpty else { return }

    totalCharacters = utterances.reduce(0) { $0 + ($1.0.speechString.count) }
    spokenCharacters = 0
    progress = 0

    #if os(iOS)
      do {
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        Logger.log("Failed to activate audio session: \(error)", level: .error, category: Logger.voice)
      }
    #endif

    // Speak first message and queue the rest
    currentMessageId = utterances.first?.1
    for (utterance, _) in utterances {
      synthesizer.speak(utterance)
    }

    isSpeaking = true
    Logger.log("Started speaking conversation (\(utterances.count) messages)", category: Logger.voice)
  }

  /// Stop speaking
  func stop() {
    guard isSpeaking else { return }

    synthesizer.stopSpeaking(at: .immediate)
    isSpeaking = false
    currentMessageId = nil
    currentUtterance = nil
    progress = 0

    #if os(iOS)
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    #endif

    Logger.log("Stopped speaking", category: Logger.voice)
  }

  /// Pause speaking
  func pause() {
    guard isSpeaking else { return }
    synthesizer.pauseSpeaking(at: .word)
  }

  /// Resume speaking
  func resume() {
    guard synthesizer.isPaused else { return }
    synthesizer.continueSpeaking()
  }

  // MARK: - Private Methods

  private func cleanTextForSpeech(_ text: String) -> String {
    var cleaned = text

    // Remove markdown formatting
    cleaned = cleaned.replacingOccurrences(of: "```[\\s\\S]*?```", with: " code block ", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "#+\\s*", with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

    // Remove excessive whitespace
    cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

    return cleaned
  }

  private func detectLanguage(_ text: String) -> DetectedLanguage {
    LanguageDetector.detect(text: text)
  }

  private func selectVoice(for language: DetectedLanguage) -> AVSpeechSynthesisVoice? {
    let languageCode: String
    switch language {
    case .arabic:
      languageCode = "ar"
    case .english, .unknown:
      languageCode = "en"
    }

    // Get all available voices
    let allVoices = AVSpeechSynthesisVoice.speechVoices()

    // Filter voices for the target language
    let languageVoices = allVoices.filter { $0.language.hasPrefix(languageCode) }

    // Prefer premium/enhanced voices
    if let premiumVoice = languageVoices.first(where: { $0.quality == .premium }) {
      return premiumVoice
    }

    // Then enhanced voices
    if let enhancedVoice = languageVoices.first(where: { $0.quality == .enhanced }) {
      return enhancedVoice
    }

    // Then any voice for that language
    if let anyVoice = languageVoices.first {
      return anyVoice
    }

    // Fallback to default
    switch language {
    case .arabic:
      return AVSpeechSynthesisVoice(language: "ar-SA")
    case .english, .unknown:
      return AVSpeechSynthesisVoice(language: "en-US")
    }
  }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {

  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didStart utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      isSpeaking = true
    }
  }

  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    // Capture value before Task to avoid Sendable issues
    let stillSpeaking = synthesizer.isSpeaking
    Task { @MainActor in
      // Check if there are more utterances queued
      if !stillSpeaking {
        isSpeaking = false
        currentMessageId = nil
        progress = 1.0
        #if os(iOS)
          try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        Logger.log("Finished speaking", category: Logger.voice)
      }
    }
  }

  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      isSpeaking = false
      currentMessageId = nil
      progress = 0
    }
  }

  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      spokenCharacters += characterRange.length
      if totalCharacters > 0 {
        progress = Double(spokenCharacters) / Double(totalCharacters)
      }
    }
  }
}

