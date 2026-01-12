import Foundation

/// Defensive wrapper around NSUbiquitousKeyValueStore that handles missing entitlements gracefully
final class SafeKVStore {
  private let store: NSUbiquitousKeyValueStore?
  private let fallbackDefaults = UserDefaults.standard
  private let isAvailable: Bool
  
    @MainActor static let shared = SafeKVStore()
  
  private init() {
    var kvStore: NSUbiquitousKeyValueStore?
    var available = false
    
    // Attempt to initialize KVS with defensive probing
    kvStore = NSUbiquitousKeyValueStore.default
    // Test if it's actually available
    if let store = kvStore {
      _ = store.dictionaryRepresentation
      available = true
    }
    
    self.store = kvStore
    self.isAvailable = available
    
    if !available {
      Logger.log(
        "iCloud KVS unavailable - using local UserDefaults fallback. Features requiring iCloud will be limited.",
        level: .info,
        category: Logger.system
      )
    }
  }
  
  // MARK: - Read operations
  
  func bool(forKey key: String) -> Bool {
    if isAvailable, let store = store {
      return store.bool(forKey: key)
    }
    return fallbackDefaults.bool(forKey: key)
  }
  
  func string(forKey key: String) -> String? {
    if isAvailable, let store = store {
      return store.string(forKey: key)
    }
    return fallbackDefaults.string(forKey: key)
  }
  
  func object(forKey key: String) -> Any? {
    if isAvailable, let store = store {
      return store.object(forKey: key)
    }
    return fallbackDefaults.object(forKey: key)
  }
  
  // MARK: - Write operations
  
  func set(_ value: Bool, forKey key: String) {
    if isAvailable, let store = store {
      store.set(value, forKey: key)
    }
    fallbackDefaults.set(value, forKey: key)
  }
  
  func set(_ value: String, forKey key: String) {
    if isAvailable, let store = store {
      store.set(value, forKey: key)
    }
    fallbackDefaults.set(value, forKey: key)
  }
  
  func set(_ value: Any?, forKey key: String) {
    if isAvailable, let store = store {
      store.set(value, forKey: key)
    }
    fallbackDefaults.set(value, forKey: key)
  }
  
  func removeObject(forKey key: String) {
    if isAvailable, let store = store {
      store.removeObject(forKey: key)
    }
    fallbackDefaults.removeObject(forKey: key)
  }
  
  // MARK: - Synchronization
  
  @discardableResult
  func synchronize() -> Bool {
    if isAvailable, let store = store {
      return store.synchronize()
    }
    // UserDefaults synchronizes automatically
    return true
  }
  
  // MARK: - Observation
  
  var didChangeExternallyNotification: Notification.Name {
    return NSUbiquitousKeyValueStore.didChangeExternallyNotification
  }
  
  var underlyingStore: NSUbiquitousKeyValueStore? {
    guard isAvailable else { return nil }
    return store
  }
}

