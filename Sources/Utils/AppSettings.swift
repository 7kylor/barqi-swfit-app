import Foundation

enum GenerationQuality: String, Codable, CaseIterable, Sendable {
  case speed
  case balanced
  case quality
}

enum ConversationAutoNaming: String, Codable, CaseIterable, Sendable {
  case always
  case smart
  case manual

  var displayName: String {
    switch self {
    case .always: return "Always Auto-Name"
    case .smart: return "Smart Detection"
    case .manual: return "Manual Only"
    }
  }

  var description: String {
    switch self {
    case .always: return "Automatically generate clever names for all conversations"
    case .smart: return "Only auto-name when confident about the topic"
    case .manual: return "Never auto-name, keep conversations as 'New Chat'"
    }
  }
}

enum AppSettings {
  private static let qualityKey = "com.taher.Mawj.settings.generationQuality"
  private static let autoTuneKey = "com.taher.Mawj.settings.autoTuneThermal"
  private static let hapticsEnabledKey = "com.taher.Mawj.settings.hapticsEnabled"
  private static let notificationsEnabledKey = "com.taher.Mawj.settings.notificationsEnabled"
  private static let appLanguageKey = "com.taher.Mawj.settings.appLanguage"
  private static let preferredModelIdKey = "com.taher.Mawj.settings.preferredModelId"
  private static let preferredModelNameKey = "com.taher.Mawj.settings.preferredModelName"
  private static let conversationAutoNamingKey = "com.taher.Mawj.settings.conversationAutoNaming"
  
  private static func preferredModelIdKey(for preset: Preset) -> String {
    "com.taher.Mawj.settings.preferredModelId.\(preset.rawValue)"
  }
  
  private static func preferredModelNameKey(for preset: Preset) -> String {
    "com.taher.Mawj.settings.preferredModelName.\(preset.rawValue)"
  }

  static var appLanguage: DetectedLanguage {
    get {
      if let raw = UserDefaults.standard.string(forKey: appLanguageKey),
         let lang = DetectedLanguage(rawValue: raw) {
        return lang
      }
      // Default to device language if available, else English
      let deviceLang = Locale.preferredLanguages.first?.lowercased() ?? "en"
      return deviceLang.hasPrefix("ar") ? .arabic : .english
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: appLanguageKey)
    }
  }

  static var generationQuality: GenerationQuality {
    get {
      if let raw = UserDefaults.standard.string(forKey: qualityKey),
        let v = GenerationQuality(rawValue: raw)
      {
        return v
      }
      return .balanced
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: qualityKey) }
  }

  static var autoTuneOnThermal: Bool {
    get { UserDefaults.standard.object(forKey: autoTuneKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: autoTuneKey) }
  }

  static var hapticsEnabled: Bool {
    get { UserDefaults.standard.object(forKey: hapticsEnabledKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: hapticsEnabledKey) }
  }

  static var notificationsEnabled: Bool {
    get { UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey) }
  }

  /// User's explicitly selected model preference (persisted across launches).
  /// This is distinct from the currently loaded model, which may change due to fallbacks.
  static var preferredModelId: UUID? {
    get {
      guard let raw = UserDefaults.standard.string(forKey: preferredModelIdKey) else { return nil }
      return UUID(uuidString: raw)
    }
    set {
      if let id = newValue {
        UserDefaults.standard.set(id.uuidString, forKey: preferredModelIdKey)
      } else {
        UserDefaults.standard.removeObject(forKey: preferredModelIdKey)
      }
    }
  }

  /// Fallback identifier to recover preference when the SwiftData store is recreated.
  static var preferredModelName: String? {
    get { UserDefaults.standard.string(forKey: preferredModelNameKey) }
    set {
      let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let v = trimmed, !v.isEmpty {
        UserDefaults.standard.set(v, forKey: preferredModelNameKey)
      } else {
        UserDefaults.standard.removeObject(forKey: preferredModelNameKey)
      }
    }
  }

  static func setPreferredModel(id: UUID, name: String) {
    preferredModelId = id
    preferredModelName = name
  }

  static func clearPreferredModel() {
    preferredModelId = nil
    preferredModelName = nil
  }
  
  // MARK: - Per-Preset Model Preferences
  
  /// Preferred model for a specific preset.
  /// This enables each preset/genre to have its own "best" default and user override.
  static func preferredModelId(for preset: Preset) -> UUID? {
    let key = preferredModelIdKey(for: preset)
    guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
    return UUID(uuidString: raw)
  }
  
  /// Fallback identifier to recover per-preset preference when the SwiftData store is recreated.
  static func preferredModelName(for preset: Preset) -> String? {
    let key = preferredModelNameKey(for: preset)
    return UserDefaults.standard.string(forKey: key)
  }
  
  static func setPreferredModel(for preset: Preset, id: UUID, name: String) {
    let idKey = preferredModelIdKey(for: preset)
    let nameKey = preferredModelNameKey(for: preset)
    UserDefaults.standard.set(id.uuidString, forKey: idKey)
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      UserDefaults.standard.set(trimmed, forKey: nameKey)
    } else {
      UserDefaults.standard.removeObject(forKey: nameKey)
    }
  }
  
  static func clearPreferredModel(for preset: Preset) {
    UserDefaults.standard.removeObject(forKey: preferredModelIdKey(for: preset))
    UserDefaults.standard.removeObject(forKey: preferredModelNameKey(for: preset))
  }

  static var conversationAutoNaming: ConversationAutoNaming {
    get {
      if let raw = UserDefaults.standard.string(forKey: conversationAutoNamingKey),
        let mode = ConversationAutoNaming(rawValue: raw)
      {
        return mode
      }
      return .smart // Default to smart detection
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: conversationAutoNamingKey) }
  }
}
