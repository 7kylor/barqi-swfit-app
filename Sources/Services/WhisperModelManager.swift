import Foundation
import Observation

#if canImport(WhisperKit)
  import WhisperKit
#endif

/// Manages Whisper model selection, download, and storage
/// Models are persisted in Application Support and survive app updates/rebuilds
@MainActor
@Observable
final class WhisperModelManager {

  // MARK: - Types

  /// Language preference for transcription
  enum LanguagePreference: String, CaseIterable, Identifiable {
    case auto = "auto"
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .auto: return L("whisper_lang_auto")
      case .arabic: return L("whisper_lang_arabic")
      case .english: return L("whisper_lang_english")
      }
    }

    var description: String {
      switch self {
      case .auto: return L("whisper_lang_auto_desc")
      case .arabic: return L("whisper_lang_arabic_desc")
      case .english: return L("whisper_lang_english_desc")
      }
    }

    /// The language code to pass to WhisperKit (nil for auto-detect)
    var whisperLanguageCode: String? {
      switch self {
      case .auto: return nil
      case .arabic: return "ar"
      case .english: return "en"
      }
    }
  }

  /// Model quality options with their WhisperKit model names
  /// Uses multilingual models for Arabic + English support
  enum ModelQuality: String, CaseIterable, Identifiable {
    case balanced = "base"
    case accurate = "small"
    case premium = "large-v3"

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .balanced: return L("whisper_quality_balanced")
      case .accurate: return L("whisper_quality_accurate")
      case .premium: return L("whisper_quality_premium")
      }
    }

    var description: String {
      switch self {
      case .balanced: return L("whisper_quality_balanced_desc")
      case .accurate: return L("whisper_quality_accurate_desc")
      case .premium: return L("whisper_quality_premium_desc")
      }
    }

    var estimatedSize: String {
      switch self {
      case .balanced: return "~140 MB"
      case .accurate: return "~460 MB"
      case .premium: return "~950 MB"
      }
    }

    /// Full WhisperKit model name for multilingual support (Arabic + English)
    var modelName: String {
      switch self {
      case .balanced: return "openai_whisper-base"
      case .accurate: return "openai_whisper-small"
      case .premium: return "openai_whisper-large-v3_947MB"
      }
    }

    /// Alternative model names to try if primary isn't available
    /// IMPORTANT: Multilingual models are prioritized first, English-only (.en) last
    var fallbackModelNames: [String] {
      switch self {
      case .balanced:
        return ["base", "whisper-base", "openai_whisper-base.en"]
      case .accurate:
        return ["small", "whisper-small", "openai_whisper-small.en"]
      case .premium:
        // All large models are multilingual
        return [
          "large-v3",
          "openai_whisper-large-v3-v20240930_626MB",
          "openai_whisper-large-v3_turbo_954MB",
          "distil-whisper_distil-large-v3_594MB",
        ]
      }
    }

    /// Multilingual-only fallback names (no .en versions)
    var multilingualFallbackNames: [String] {
      switch self {
      case .balanced:
        return ["base", "whisper-base"]
      case .accurate:
        return ["small", "whisper-small"]
      case .premium:
        return [
          "large-v3",
          "openai_whisper-large-v3-v20240930_626MB",
          "openai_whisper-large-v3_turbo_954MB",
          "distil-whisper_distil-large-v3_594MB",
        ]
      }
    }

    /// All possible name patterns that could match this quality
    var allPossibleNames: [String] {
      [modelName] + fallbackModelNames
    }

    /// Languages supported by this model
    var supportedLanguages: String {
      // All non-.en models support 99+ languages including Arabic
      return L("whisper_supported_languages")
    }

    /// Check if a model name is multilingual (supports Arabic)
    static func isMultilingual(_ modelName: String) -> Bool {
      // English-only models end with .en
      !modelName.lowercased().hasSuffix(".en")
    }
  }

  enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)
  }

  // MARK: - Singleton

  static let shared = WhisperModelManager()

  // MARK: - Bundled Model Constants

  /// The bundled Whisper base (balanced) model folder name in the app bundle
  /// This model is ALWAYS available and ships with the app
  static let bundledModelFolderName = "openai_whisper-base"

  /// Path to the bundled Whisper base (balanced) model in the app bundle
  /// This is a CORE part of the app and is ALWAYS available
  /// The model is located at: BundledModels/openai_whisper-base/
  static var bundledModelFolder: String? {
    let bundle = Bundle.main
    let fm = FileManager.default

    // 1. Primary location: BundledModels/openai_whisper-base folder (folder reference)
    if let resourceURL = bundle.resourceURL {
      let bundledPath = resourceURL.appendingPathComponent(
        "BundledModels/\(bundledModelFolderName)")
      if fm.fileExists(atPath: bundledPath.path) {
        return bundledPath.path
      }
    }

    // 2. Direct resource path (if added as folder reference at root)
    if let path = bundle.path(forResource: bundledModelFolderName, ofType: nil) {
      return path
    }

    // 3. Check in BundledModels directory using Bundle API
    if let path = bundle.path(
      forResource: bundledModelFolderName, ofType: nil, inDirectory: "BundledModels")
    {
      return path
    }

    // 4. Fallback: Check if files are at bundle root (Xcode flattened structure)
    // This happens when folder reference isn't used correctly
    if let encoderPath = bundle.path(forResource: "AudioEncoder", ofType: "mlmodelc") {
      // Files are at root - return bundle resource path as the "folder"
      // We'll need special handling in verification
      let parentDir = (encoderPath as NSString).deletingLastPathComponent
      // Verify it also has TextDecoder
      let decoderPath = (parentDir as NSString).appendingPathComponent("TextDecoder.mlmodelc")
      if fm.fileExists(atPath: decoderPath) {
        return parentDir
      }
    }

    // 5. Check openai_whisper-base directly in bundle (another possible structure)
    if let resourceURL = bundle.resourceURL {
      let directPath = resourceURL.appendingPathComponent(bundledModelFolderName)
      if fm.fileExists(atPath: directPath.path) {
        return directPath.path
      }
    }

    return nil
  }

  /// Check if the bundled model is available and valid
  static var isBundledModelAvailable: Bool {
    guard let folder = bundledModelFolder else {
      // Log only once during init (not every call)
      return false
    }
    let fm = FileManager.default
    let encoderPath = (folder as NSString).appendingPathComponent("AudioEncoder.mlmodelc")
    let decoderPath = (folder as NSString).appendingPathComponent("TextDecoder.mlmodelc")
    let hasEncoder = fm.fileExists(atPath: encoderPath)
    let hasDecoder = fm.fileExists(atPath: decoderPath)
    return hasEncoder && hasDecoder
  }

  /// Debug method to check bundled model status
  static func logBundledModelStatus() {
    let bundle = Bundle.main
    let fm = FileManager.default

    // Log bundle path for debugging
    Logger.log("Bundle path: \(bundle.bundlePath)", category: Logger.voice)

    // Check all possible locations
    var foundPath: String?

    // 1. Check BundledModels/openai_whisper-base
    if let resourceURL = bundle.resourceURL {
      let path1 = resourceURL.appendingPathComponent("BundledModels/\(bundledModelFolderName)").path
      if fm.fileExists(atPath: path1) {
        Logger.log("Found at BundledModels/: \(path1)", category: Logger.voice)
        foundPath = path1
      }
    }

    // 2. Check direct resource (folder reference at root)
    if let path2 = bundle.path(forResource: bundledModelFolderName, ofType: nil) {
      Logger.log("Found as direct resource: \(path2)", category: Logger.voice)
      foundPath = foundPath ?? path2
    }

    // 3. Check in BundledModels directory
    if let path3 = bundle.path(
      forResource: bundledModelFolderName, ofType: nil, inDirectory: "BundledModels")
    {
      Logger.log("Found in BundledModels directory: \(path3)", category: Logger.voice)
      foundPath = foundPath ?? path3
    }

    // 4. Check if AudioEncoder.mlmodelc exists directly in bundle (Xcode might flatten)
    if let path4 = bundle.path(forResource: "AudioEncoder", ofType: "mlmodelc") {
      Logger.log("Found AudioEncoder.mlmodelc at root: \(path4)", category: Logger.voice)
      // If found at root, the parent directory is the model folder
      let parentDir = (path4 as NSString).deletingLastPathComponent
      foundPath = foundPath ?? parentDir
    }

    // 5. List contents of bundle to help debug
    if let resourceURL = bundle.resourceURL {
      if let contents = try? fm.contentsOfDirectory(atPath: resourceURL.path) {
        let relevantItems = contents.filter {
          $0.contains("Bundled") || $0.contains("whisper") || $0.contains("Audio")
            || $0.contains("Text") || $0.contains("Mel") || $0.hasPrefix("openai")
        }
        if !relevantItems.isEmpty {
          Logger.log(
            "Relevant bundle contents: \(relevantItems.joined(separator: ", "))",
            category: Logger.voice)
        }
      }
    }

    if let folder = foundPath {
      let encoderPath = (folder as NSString).appendingPathComponent("AudioEncoder.mlmodelc")
      let decoderPath = (folder as NSString).appendingPathComponent("TextDecoder.mlmodelc")
      Logger.log("Bundled model folder: \(folder)", category: Logger.voice)
      Logger.log(
        "AudioEncoder exists: \(fm.fileExists(atPath: encoderPath))", category: Logger.voice)
      Logger.log(
        "TextDecoder exists: \(fm.fileExists(atPath: decoderPath))", category: Logger.voice)
    } else {
      Logger.log(
        "Bundled model folder not found - checked all locations", level: .info,
        category: Logger.voice)
    }
  }

  // MARK: - Observable State

  private(set) var selectedQuality: ModelQuality
  private(set) var selectedLanguage: LanguagePreference
  private(set) var downloadState: DownloadState = .notDownloaded
  private(set) var isLoadingModel: Bool = false  // True when model is being loaded/initialized
  private(set) var loadingProgress: Double = 0  // Loading progress (0.0 to 1.0)
  private(set) var availableModels: [String] = []
  private(set) var activeModelName: String?

  // MARK: - Private Properties

  private let userDefaultsKey = "whisper_model_quality"
  private let languagePreferenceKey = "whisper_language_preference"
  private let downloadedModelKey = "whisper_downloaded_model"
  private let downloadedModelFolderKey = "whisper_downloaded_model_folder"
  private let cachedModelsKey = "whisper_cached_models"  // Cache all discovered models
  private var isCheckingState = false
  private var hasCompletedInitialVerification = false

  /// The folder path where the model is stored
  private(set) var activeModelFolder: String?

  /// Cache of all discovered models: [modelName: folderPath]
  private var cachedModelPaths: [String: String] = [:]

  /// Persistent directory for storing Whisper models (survives app rebuilds)
  private var persistentModelsDirectory: URL {
    // Use Application Support directory which persists across app updates/rebuilds
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let whisperDir = appSupport.appendingPathComponent("WhisperModels", isDirectory: true)

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: whisperDir.path) {
      try? FileManager.default.createDirectory(at: whisperDir, withIntermediateDirectories: true)
      Logger.log(
        "Created persistent Whisper models directory: \(whisperDir.path)", category: Logger.voice)
    }

    return whisperDir
  }

  // MARK: - Initialization

  init() {
    // Load saved quality preference, default to balanced for good quality
    if let savedQuality = UserDefaults.standard.string(forKey: userDefaultsKey),
      let quality = ModelQuality(rawValue: savedQuality)
    {
      selectedQuality = quality
    } else {
      selectedQuality = .balanced  // Default to balanced for good quality
    }

    // Load saved language preference, default to auto-detect
    if let savedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey),
      let language = LanguagePreference(rawValue: savedLanguage)
    {
      selectedLanguage = language
    } else {
      selectedLanguage = .auto  // Default to auto-detect (supports Arabic + English)
    }

    // Load cached model paths from UserDefaults for instant access
    if let cachedData = UserDefaults.standard.data(forKey: cachedModelsKey),
      let cached = try? JSONDecoder().decode([String: String].self, from: cachedData)
    {
      cachedModelPaths = cached
      Logger.log("Loaded \(cached.count) cached Whisper model paths", category: Logger.voice)
    }

    // Log bundled model status for debugging
    Self.logBundledModelStatus()

    // PRIORITY 1: Check for bundled model (ALWAYS available, ships with app)
    if Self.isBundledModelAvailable, let bundledFolder = Self.bundledModelFolder {
      // Bundled model is always available for balanced quality
      if selectedQuality == .balanced {
        activeModelName = Self.bundledModelFolderName
        activeModelFolder = bundledFolder
        downloadState = .downloaded
        Logger.log(
          "Using bundled Whisper model (ships with app): \(bundledFolder)", category: Logger.voice)
      } else {
        // User wants a higher quality model, check if downloaded
        initializeForHigherQualityModel()
      }
    } else {
      // Bundled model not found - fall back to checking downloaded models
      // NOTE: Once BundledModels folder is added to Xcode, bundled model will be used
      Logger.log(
        "Bundled Whisper model not available - using downloaded model fallback", level: .info,
        category: Logger.voice)
      initializeFromSavedState()
    }

    // Ensure persistent directory exists
    _ = persistentModelsDirectory

    // Verify and discover models in background (non-blocking)
    Task {
      await verifyAndDiscoverModels()
    }
  }

  /// Initialize for higher quality models (user upgraded from default)
  private func initializeForHigherQualityModel() {
    if let savedModel = UserDefaults.standard.string(forKey: downloadedModelKey),
      !savedModel.isEmpty,
      let savedFolder = UserDefaults.standard.string(forKey: downloadedModelFolderKey),
      FileManager.default.fileExists(atPath: savedFolder)
    {
      activeModelName = savedModel
      activeModelFolder = savedFolder
      downloadState = .downloaded
      Logger.log(
        "Using downloaded higher-quality Whisper model: \(savedModel)", category: Logger.voice)
    } else {
      // Higher quality model not downloaded yet - mark as needing download
      // But bundled model is still available as fallback
      downloadState = .notDownloaded
      Logger.log(
        "Higher quality Whisper model not downloaded - bundled model available as fallback",
        category: Logger.voice)
    }
  }

  /// Initialize from saved state (fallback when bundled model not available)
  private func initializeFromSavedState() {
    if let savedModel = UserDefaults.standard.string(forKey: downloadedModelKey),
      !savedModel.isEmpty
    {
      activeModelName = savedModel
      activeModelFolder = UserDefaults.standard.string(forKey: downloadedModelFolderKey)

      // Quick synchronous check if folder exists (fast path)
      if let folder = activeModelFolder, FileManager.default.fileExists(atPath: folder) {
        downloadState = .downloaded
        Logger.log("Whisper model ready (fast path): \(savedModel)", category: Logger.voice)
      } else if let cachedPath = cachedModelPaths[savedModel],
        FileManager.default.fileExists(atPath: cachedPath)
      {
        // Use cached path if saved path doesn't exist
        activeModelFolder = cachedPath
        saveModelState(name: savedModel, folder: cachedPath)
        downloadState = .downloaded
        Logger.log("Whisper model ready (from cache): \(savedModel)", category: Logger.voice)
      } else {
        // Mark as downloaded initially, verify in background
        downloadState = .downloaded
        Logger.log(
          "Whisper model loaded from settings, will verify: \(savedModel)", category: Logger.voice)
      }
    }
  }

  // MARK: - State Persistence Helpers

  private func saveModelState(name: String, folder: String) {
    UserDefaults.standard.set(name, forKey: downloadedModelKey)
    UserDefaults.standard.set(folder, forKey: downloadedModelFolderKey)

    // Update cache
    cachedModelPaths[name] = folder
    if let data = try? JSONEncoder().encode(cachedModelPaths) {
      UserDefaults.standard.set(data, forKey: cachedModelsKey)
    }
  }

  private func clearModelState() {
    activeModelName = nil
    activeModelFolder = nil
    UserDefaults.standard.removeObject(forKey: downloadedModelKey)
    UserDefaults.standard.removeObject(forKey: downloadedModelFolderKey)
    downloadState = .notDownloaded
  }

  // MARK: - Public Methods

  /// Select a model quality
  func selectQuality(_ quality: ModelQuality) {
    guard selectedQuality != quality else { return }

    selectedQuality = quality
    UserDefaults.standard.set(quality.rawValue, forKey: userDefaultsKey)

    // PRIORITY: For balanced quality, ALWAYS use bundled model (ships with app)
    if quality == .balanced, Self.isBundledModelAvailable, let bundledFolder = Self.bundledModelFolder {
      activeModelName = Self.bundledModelFolderName
      activeModelFolder = bundledFolder
      downloadState = .downloaded
      Logger.log(
        "Using bundled Whisper model for balanced quality (ships with app)", category: Logger.voice)
      return
    }

    // Check if this quality's model is already active
    if let active = activeModelName, modelMatchesQuality(modelName: active, quality: quality) {
      downloadState = .downloaded
      Logger.log(
        "Model for quality \(quality.displayName) already active: \(active)", category: Logger.voice
      )
      return
    }

    // Check cache first (fastest)
    for name in quality.allPossibleNames {
      if let cachedPath = cachedModelPaths[name], FileManager.default.fileExists(atPath: cachedPath)
      {
        activeModelName = name
        activeModelFolder = cachedPath
        saveModelState(name: name, folder: cachedPath)
        downloadState = .downloaded
        Logger.log(
          "Found cached model for quality \(quality.displayName): \(name)", category: Logger.voice)
        return
      }
    }

    // Search persistent directory
    if let found = findModelForQuality(quality) {
      activeModelName = found.name
      activeModelFolder = found.path
      saveModelState(name: found.name, folder: found.path)
      downloadState = .downloaded
      Logger.log(
        "Found model for quality \(quality.displayName): \(found.name)", category: Logger.voice)
      return
    }

    // No model found - but DON'T clear the current model state
    // Just mark that this quality needs download
    downloadState = .notDownloaded
    Logger.log(
      "No model found for quality \(quality.displayName), will need to download",
      category: Logger.voice)
  }

  /// Select language preference for transcription
  func selectLanguage(_ language: LanguagePreference) {
    guard selectedLanguage != language else { return }

    selectedLanguage = language
    UserDefaults.standard.set(language.rawValue, forKey: languagePreferenceKey)

    // If user selects Arabic, check model compatibility
    if language == .arabic, let activeModel = activeModelName {
      if !ModelQuality.isMultilingual(activeModel) {
        Logger.log(
          "Current model '\(activeModel)' does not support Arabic. Please download a multilingual model.",
          level: .error, category: Logger.voice)
      } else if !hasGoodArabicSupport {
        // Tiny models struggle with Arabic transcription
        Logger.log(
          "Current model '\(activeModel)' has limited Arabic support. For better Arabic transcription, consider using '\(WhisperModelManager.recommendedQualityForArabic.displayName)' quality.",
          level: .info, category: Logger.voice)
      }
    }

    Logger.log("Selected Whisper language: \(language.displayName)", category: Logger.voice)
  }

  /// Get the language code for transcription
  func getLanguageForTranscription() -> String? {
    return selectedLanguage.whisperLanguageCode
  }

  /// Check if the current model supports Arabic (is multilingual)
  var supportsArabic: Bool {
    guard let modelName = activeModelName else { return true }  // Assume yes if no model yet
    return ModelQuality.isMultilingual(modelName)
  }

  /// Check if the current model has good Arabic transcription quality
  /// Tiny models struggle with Arabic - recommend at least base/small for Arabic
  var hasGoodArabicSupport: Bool {
    guard let modelName = activeModelName else { return false }
    let nameLower = modelName.lowercased()

    // Tiny models have poor Arabic transcription - they output "[Speaking in Arabic]" instead
    if nameLower.contains("tiny") {
      return false
    }

    // English-only models don't support Arabic at all
    if nameLower.hasSuffix(".en") {
      return false
    }

    // Base, small, large models have acceptable Arabic support
    return true
  }

  /// Get the recommended model quality for Arabic transcription
  static var recommendedQualityForArabic: ModelQuality {
    // Small model provides good balance between size and Arabic quality
    return .accurate  // small model - 460MB
  }

  /// Check if a model name matches a quality level
  private func modelMatchesQuality(modelName: String, quality: ModelQuality) -> Bool {
    let nameLower = modelName.lowercased()
    for possibleName in quality.allPossibleNames {
      if nameLower.contains(possibleName.lowercased())
        || possibleName.lowercased().contains(nameLower)
      {
        return true
      }
    }
    return false
  }

  /// Find a model for a specific quality in persistent storage
  private func findModelForQuality(_ quality: ModelQuality) -> (name: String, path: String)? {
    for name in quality.allPossibleNames {
      if let path = findModelInPersistentDirectory(modelName: name) {
        return (name, path)
      }
    }
    return nil
  }

  /// Download the selected model to persistent storage
  func downloadModel() async {
    #if canImport(WhisperKit)
      // Prevent multiple simultaneous downloads
      if case .downloading = downloadState { return }

      downloadState = .downloading(progress: 0)
      Logger.log(
        "Starting download of Whisper model: \(selectedQuality.modelName)",
        category: Logger.voice
      )

      do {
        // Fetch available models
        let recommended = WhisperKit.recommendedModels()
        availableModels = recommended.supported
        Logger.log(
          "Available WhisperKit models: \(recommended.supported.joined(separator: ", "))",
          category: Logger.voice
        )

        // Find the best available model
        let modelToDownload = findBestAvailableModel(
          primary: selectedQuality.modelName,
          fallbacks: selectedQuality.fallbackModelNames,
          available: recommended.supported
        )

        guard let actualModelName = modelToDownload else {
          downloadState = .failed(L("no_compatible_model"))
          Logger.log(
            "No compatible model found for \(selectedQuality.displayName)",
            level: .error,
            category: Logger.voice
          )
          return
        }

        Logger.log(
          "Downloading model: \(actualModelName) to persistent storage", category: Logger.voice)
        downloadState = .downloading(progress: 0.1)

        // Download the model to our persistent directory
        let progressHandler: @Sendable (Progress) -> Void = { [weak self] progress in
          Task { @MainActor in
            guard let self = self else { return }
            if case .downloading = self.downloadState {
              self.downloadState = .downloading(progress: progress.fractionCompleted)
            }
          }
        }

        // Download to persistent Application Support directory
        let persistentDir = persistentModelsDirectory
        Logger.log("Using persistent directory: \(persistentDir.path)", category: Logger.voice)

        let modelURL = try await WhisperKit.download(
          variant: actualModelName,
          downloadBase: persistentDir,
          from: "argmaxinc/whisperkit-coreml",
          progressCallback: progressHandler
        )

        let folderPath = modelURL.path
        Logger.log("Model downloaded to persistent folder: \(folderPath)", category: Logger.voice)

        // Verify the download was successful
        guard verifyModelFiles(at: modelURL) else {
          downloadState = .failed("Model download incomplete - missing required files")
          Logger.log(
            "Download incomplete: AudioEncoder or TextDecoder missing", level: .error,
            category: Logger.voice)
          return
        }

        // Save the downloaded model
        activeModelName = actualModelName
        activeModelFolder = folderPath
        saveModelState(name: actualModelName, folder: folderPath)
        downloadState = .downloaded

        Logger.log(
          "Whisper model downloaded and persisted: \(actualModelName) at \(folderPath)",
          category: Logger.voice)

      } catch {
        downloadState = .failed(error.localizedDescription)
        Logger.log(
          "Failed to download Whisper model: \(error.localizedDescription)",
          level: .error,
          category: Logger.voice
        )
      }
    #else
      downloadState = .failed("WhisperKit not available")
    #endif
  }

  /// Verify model files exist at path - checks all required files including tokenizer
  private func verifyModelFiles(at url: URL) -> Bool {
    let fm = FileManager.default

    // Required model files
    let encoderPath = url.appendingPathComponent("AudioEncoder.mlmodelc").path
    let decoderPath = url.appendingPathComponent("TextDecoder.mlmodelc").path

    // Also check for tokenizer - required for transcription
    // Check for multiple possible tokenizer locations
    let tokenizerPaths = [
      url.appendingPathComponent("tokenizer.json").path,
      url.appendingPathComponent("config.json").path,
    ]

    let hasEncoder = fm.fileExists(atPath: encoderPath)
    let hasDecoder = fm.fileExists(atPath: decoderPath)
    let hasTokenizer = tokenizerPaths.contains { fm.fileExists(atPath: $0) }

    // Check for .incomplete files which indicate failed downloads
    if let contents = try? fm.contentsOfDirectory(atPath: url.path) {
      let hasIncompleteFiles = contents.contains { $0.hasSuffix(".incomplete") }
      if hasIncompleteFiles {
        Logger.log(
          "Model at \(url.lastPathComponent) has incomplete files - download may have failed",
          level: .error, category: Logger.voice
        )
        return false
      }
    }

    if !hasEncoder || !hasDecoder {
      return false
    }

    // For large models, tokenizer is critical - warn if missing
    if !hasTokenizer {
      Logger.log(
        "Model at \(url.lastPathComponent) missing tokenizer files - may fail to load",
        level: .info, category: Logger.voice
      )
    }

    return hasEncoder && hasDecoder
  }

  /// Verify model files exist at path string
  private func verifyModelFiles(atPath path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    return verifyModelFiles(at: url)
  }

  /// Check if model has complete tokenizer files (required for actual use)
  /// Note: WhisperKit can download tokenizer at runtime if config.json is present
  func hasCompleteTokenizer(atPath path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    let fm = FileManager.default

    // Check for .incomplete files first - this indicates a failed download
    if let contents = try? fm.contentsOfDirectory(atPath: path) {
      let hasIncompleteFiles = contents.contains { $0.hasSuffix(".incomplete") }
      if hasIncompleteFiles {
        return false
      }
    }

    // Accept any of these configurations as valid:
    // 1. tokenizer.json (explicit tokenizer)
    // 2. vocab.json (alternative tokenizer format)
    // 3. config.json (WhisperKit can download tokenizer at runtime)
    let validConfigPaths = [
      url.appendingPathComponent("tokenizer.json").path,
      url.appendingPathComponent("vocab.json").path,
      url.appendingPathComponent("config.json").path,
    ]

    return validConfigPaths.contains { fm.fileExists(atPath: $0) }
  }

  /// Delete model with incomplete files and prepare for re-download
  func deleteIncompleteModel(atPath path: String) {
    let url = URL(fileURLWithPath: path)
    do {
      try FileManager.default.removeItem(at: url)
      Logger.log("Deleted incomplete model at: \(path)", category: Logger.voice)

      // Clear from cache
      cachedModelPaths = cachedModelPaths.filter { $0.value != path }
      if let data = try? JSONEncoder().encode(cachedModelPaths) {
        UserDefaults.standard.set(data, forKey: cachedModelsKey)
      }

      // If this was the active model, clear it
      if activeModelFolder == path {
        clearModelState()
      }
    } catch {
      Logger.log(
        "Failed to delete incomplete model: \(error.localizedDescription)", level: .error,
        category: Logger.voice)
    }
  }

  /// Comprehensive verification and discovery of models - runs on startup
  private func verifyAndDiscoverModels() async {
    guard !isCheckingState else { return }
    isCheckingState = true
    defer {
      isCheckingState = false
      hasCompletedInitialVerification = true
    }

    #if canImport(WhisperKit)
      Logger.log("Starting comprehensive Whisper model verification...", category: Logger.voice)

      // PRIORITY: Verify bundled model is available (ships with app, always works)
      if Self.isBundledModelAvailable {
        Logger.log("Bundled Whisper model verified and ready", category: Logger.voice)

        // For balanced quality, use bundled model directly
        if selectedQuality == .balanced {
          activeModelName = Self.bundledModelFolderName
          activeModelFolder = Self.bundledModelFolder
          downloadState = .downloaded
          return
        }
      } else {
        Logger.log(
          "WARNING: Bundled Whisper model not found in app bundle", level: .error,
          category: Logger.voice)
      }

      // Scan persistent directory for downloaded models (for higher quality options)
      await scanAndCacheAllModels()

      // If we have an active model, verify it
      if let savedModel = activeModelName {
        // Check saved folder path first
        if let folderPath = activeModelFolder, verifyModelFiles(atPath: folderPath) {
          downloadState = .downloaded
          Logger.log(
            "Verified active Whisper model: \(savedModel) at \(folderPath)", category: Logger.voice)
          return
        }

        // Try cached path
        if let cachedPath = cachedModelPaths[savedModel], verifyModelFiles(atPath: cachedPath) {
          activeModelFolder = cachedPath
          saveModelState(name: savedModel, folder: cachedPath)
          downloadState = .downloaded
          Logger.log("Recovered Whisper model from cache: \(savedModel)", category: Logger.voice)
          return
        }

        // Search for the model in persistent directory
        if let foundPath = findModelInPersistentDirectory(modelName: savedModel) {
          activeModelFolder = foundPath
          saveModelState(name: savedModel, folder: foundPath)
          downloadState = .downloaded
          Logger.log(
            "Found Whisper model in persistent directory: \(savedModel)", category: Logger.voice)
          return
        }

        // Model not found - but check if ANY model exists that we can use
        if let anyModel = cachedModelPaths.first {
          activeModelName = anyModel.key
          activeModelFolder = anyModel.value
          saveModelState(name: anyModel.key, folder: anyModel.value)
          downloadState = .downloaded
          Logger.log("Using alternative Whisper model: \(anyModel.key)", category: Logger.voice)
          return
        }

        // No models found at all
        Logger.log("No Whisper models found, will need to download", category: Logger.voice)
        clearModelState()
      } else {
        // No saved model, but check if any exist
        if let firstModel = cachedModelPaths.first {
          activeModelName = firstModel.key
          activeModelFolder = firstModel.value
          saveModelState(name: firstModel.key, folder: firstModel.value)
          downloadState = .downloaded
          Logger.log("Discovered existing Whisper model: \(firstModel.key)", category: Logger.voice)
        } else {
          downloadState = .notDownloaded
        }
      }
    #else
      downloadState = .notDownloaded
    #endif
  }

  /// Verify that the saved model is still valid
  private func verifyDownloadedModel() async {
    await verifyAndDiscoverModels()
  }

  /// Scan persistent directory and cache ALL discovered models
  private func scanAndCacheAllModels() async {
    #if canImport(WhisperKit)
      let persistentDir = persistentModelsDirectory
      var discoveredModels: [String: String] = [:]

      Logger.log("Scanning for Whisper models in: \(persistentDir.path)", category: Logger.voice)

      // Recursive scan function
      func scanDirectory(_ directory: URL, depth: Int = 0) {
        guard depth < 5 else { return }  // Prevent infinite recursion

        guard
          let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
          )
        else { return }

        for item in contents {
          guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            continue
          }

          // Check if this folder contains model files
          if verifyModelFiles(at: item) {
            let modelName = item.lastPathComponent
            discoveredModels[modelName] = item.path
            Logger.log(
              "Discovered Whisper model: \(modelName) at \(item.path)", category: Logger.voice)
          } else {
            // Recurse into subdirectories
            scanDirectory(item, depth: depth + 1)
          }
        }
      }

      scanDirectory(persistentDir)

      // Update cache
      cachedModelPaths = discoveredModels
      if let data = try? JSONEncoder().encode(discoveredModels) {
        UserDefaults.standard.set(data, forKey: cachedModelsKey)
      }

      Logger.log("Cached \(discoveredModels.count) Whisper models", category: Logger.voice)
    #endif
  }

  /// Find a specific model in the persistent directory
  private func findModelInPersistentDirectory(modelName: String) -> String? {
    let persistentDir = persistentModelsDirectory
    let nameLower = modelName.lowercased()

    // Check cache first
    if let cached = cachedModelPaths[modelName] {
      if verifyModelFiles(atPath: cached) {
        return cached
      }
    }

    // Check for partial matches in cache
    for (cachedName, cachedPath) in cachedModelPaths {
      let cachedLower = cachedName.lowercased()
      if cachedLower.contains(nameLower) || nameLower.contains(cachedLower) {
        if verifyModelFiles(atPath: cachedPath) {
          return cachedPath
        }
      }
    }

    // Check direct path
    let directPath = persistentDir.appendingPathComponent(modelName)
    if verifyModelFiles(at: directPath) {
      // Update cache
      cachedModelPaths[modelName] = directPath.path
      return directPath.path
    }

    // Search all subdirectories
    func searchDirectory(_ directory: URL, depth: Int = 0) -> String? {
      guard depth < 5 else { return nil }

      guard
        let contents = try? FileManager.default.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: [.isDirectoryKey]
        )
      else { return nil }

      for item in contents {
        guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
          continue
        }

        let folderName = item.lastPathComponent.lowercased()

        // Check if this folder matches the model name
        if folderName.contains(nameLower) || nameLower.contains(folderName) {
          if verifyModelFiles(at: item) {
            // Update cache
            cachedModelPaths[item.lastPathComponent] = item.path
            return item.path
          }
        }

        // Check nested path
        let nestedPath = item.appendingPathComponent(modelName)
        if verifyModelFiles(at: nestedPath) {
          cachedModelPaths[modelName] = nestedPath.path
          return nestedPath.path
        }

        // Recurse
        if let found = searchDirectory(item, depth: depth + 1) {
          return found
        }
      }

      return nil
    }

    return searchDirectory(persistentDir)
  }

  /// Delete downloaded model to free space
  func deleteModel() {
    // Delete the actual model files from persistent storage
    if let folderPath = activeModelFolder {
      let folderURL = URL(fileURLWithPath: folderPath)
      do {
        try FileManager.default.removeItem(at: folderURL)
        Logger.log("Deleted Whisper model files at: \(folderPath)", category: Logger.voice)

        // Remove from cache
        if let name = activeModelName {
          cachedModelPaths.removeValue(forKey: name)
          if let data = try? JSONEncoder().encode(cachedModelPaths) {
            UserDefaults.standard.set(data, forKey: cachedModelsKey)
          }
        }
      } catch {
        Logger.log(
          "Failed to delete model files: \(error.localizedDescription)", level: .error,
          category: Logger.voice)
      }
    }

    clearModelState()
    Logger.log("Whisper model deleted", category: Logger.voice)
  }

  /// Get the model folder path for loading - with verification
  /// ALWAYS returns a valid path: bundled model for balanced quality, or downloaded model for others
  func getModelFolder() -> String? {
    // PRIORITY 1: For balanced quality, ALWAYS use the bundled model (ships with app)
    // This ensures instant availability without any download
    if selectedQuality == .balanced {
      if let bundledFolder = Self.bundledModelFolder, verifyModelFiles(atPath: bundledFolder) {
        // Update state to reflect we're using bundled model
        if activeModelFolder != bundledFolder {
          activeModelName = Self.bundledModelFolderName
          activeModelFolder = bundledFolder
          downloadState = .downloaded
          Logger.log("Using bundled Whisper model: \(bundledFolder)", category: Logger.voice)
        }
        return bundledFolder
      }
    }

    // PRIORITY 2: For other qualities, check the active model folder
    if let folder = activeModelFolder, verifyModelFiles(atPath: folder) {
      return folder
    }

    // Try to recover from cache
    if let name = activeModelName, let cached = cachedModelPaths[name] {
      if verifyModelFiles(atPath: cached) {
        activeModelFolder = cached
        saveModelState(name: name, folder: cached)
        return cached
      }
    }

    // Try to find the model again
    if let name = activeModelName, let found = findModelInPersistentDirectory(modelName: name) {
      activeModelFolder = found
      saveModelState(name: name, folder: found)
      return found
    }

    // FALLBACK: Always return bundled model if available (never fail)
    if let bundledFolder = Self.bundledModelFolder, verifyModelFiles(atPath: bundledFolder) {
      Logger.log("Falling back to bundled Whisper model", category: Logger.voice)
      activeModelName = Self.bundledModelFolderName
      activeModelFolder = bundledFolder
      downloadState = .downloaded
      return bundledFolder
    }

    return activeModelFolder
  }

  /// Get the model name to use for transcription
  func getModelNameForTranscription() -> String {
    if let active = activeModelName {
      return active
    }
    // Default to bundled model name for balanced quality
    if selectedQuality == .balanced {
      return Self.bundledModelFolderName
    }
    return selectedQuality.modelName
  }

  /// Check if a model is ready to use (downloaded and verified)
  /// ALWAYS returns true for balanced quality (bundled model is always available)
  var isModelReady: Bool {
    // Bundled model is ALWAYS ready for balanced quality
    if selectedQuality == .balanced, Self.isBundledModelAvailable {
      return true
    }

    // For other qualities, check download state
    guard case .downloaded = downloadState else { return false }
    guard let folder = activeModelFolder else { return false }
    return verifyModelFiles(atPath: folder)
  }

  /// Force refresh of model state - useful after app updates
  func refreshModelState() async {
    isCheckingState = false
    hasCompletedInitialVerification = false
    await verifyAndDiscoverModels()
  }

  /// Get all available (downloaded) models
  var downloadedModels: [String] {
    return Array(cachedModelPaths.keys)
  }

  // MARK: - Loading State Management

  /// Start model loading state
  func startLoading() {
    isLoadingModel = true
    loadingProgress = 0.1
    Logger.log("Whisper model loading started", category: Logger.voice)
  }

  /// Update loading progress
  func updateLoadingProgress(_ progress: Double) {
    loadingProgress = min(1.0, max(0.0, progress))
  }

  /// Finish model loading state
  func finishLoading(success: Bool) {
    isLoadingModel = false
    loadingProgress = success ? 1.0 : 0.0
    Logger.log(
      "Whisper model loading finished: \(success ? "success" : "failed")", category: Logger.voice)
  }

  // MARK: - Private Helpers

  /// Find the best available model from primary and fallbacks
  private func findBestAvailableModel(
    primary: String,
    fallbacks: [String],
    available: [String]
  ) -> String? {
    // Check exact match for primary
    if available.contains(primary) {
      return primary
    }

    // Check if any available model contains our primary name
    if let match = available.first(where: { $0.contains(primary) }) {
      return match
    }

    // Try fallbacks in order
    for fallback in fallbacks {
      if available.contains(fallback) {
        return fallback
      }
      // Check partial match
      if let match = available.first(where: { $0.contains(fallback) }) {
        return match
      }
    }

    // Last resort: return first available model
    return available.first
  }

}
