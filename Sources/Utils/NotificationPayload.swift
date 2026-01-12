import Foundation

// ToastKind is defined in Toast.swift

/// Typed payload structures for notifications to replace [String: Any]
struct ToastNotificationPayload {
  let message: String
  let kind: ToastKind
  
  static func from(_ dictionary: [String: Any]) -> ToastNotificationPayload? {
    guard let message = dictionary["message"] as? String else {
      return nil
    }
    // Parse kind from dictionary, default to .error
    let kindString = dictionary["kind"] as? String ?? "error"
    let kind: ToastKind = {
      switch kindString {
      case "info": return .info
      case "success": return .success
      case "warning": return .warning
      case "error": return .error
      default: return .error
      }
    }()
    return ToastNotificationPayload(message: message, kind: kind)
  }
  
  func toDictionary() -> [String: String] {
    let kindString: String = {
      switch kind {
      case .info: return "info"
      case .success: return "success"
      case .warning: return "warning"
      case .error: return "error"
      }
    }()
    return ["message": message, "kind": kindString]
  }
}

struct DiagnosticsNotificationPayload {
  let tokensPerSec: Double?
  let ttfbMs: Int?
  let memoryMB: Int?
  
  static func from(_ dictionary: [String: Any]) -> DiagnosticsNotificationPayload {
    return DiagnosticsNotificationPayload(
      tokensPerSec: dictionary["tokensPerSec"] as? Double,
      ttfbMs: dictionary["ttfbMs"] as? Int,
      memoryMB: dictionary["memoryMB"] as? Int
    )
  }
  
  func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [:]
    if let tokensPerSec = tokensPerSec {
      dict["tokensPerSec"] = tokensPerSec
    }
    if let ttfbMs = ttfbMs {
      dict["ttfbMs"] = ttfbMs
    }
    if let memoryMB = memoryMB {
      dict["memoryMB"] = memoryMB
    }
    return dict
  }
}

