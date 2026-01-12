import Foundation

struct PaywallHelper {
  static func present(
    for feature: GatedFeature,
    source: String? = nil,
    message: String? = nil
  ) {
    var userInfo: [String: String] = ["feature": feature.rawValue]
    if let source { userInfo["source"] = source }
    if let message { userInfo["message"] = message }
    NotificationCenter.default.post(
      name: .presentPaywall,
      object: nil,
      userInfo: userInfo
    )
  }
}

