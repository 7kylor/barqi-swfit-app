import SwiftUI

extension View {
  #if os(macOS)
    func macHoverEffect() -> some View {
      self
        .onHover { hovering in
          if hovering {
            NSCursor.pointingHand.push()
          } else {
            NSCursor.pop()
          }
        }
    }
  #else
    // No-op for other platforms
    func macHoverEffect() -> some View {
      self
    }
  #endif
}
