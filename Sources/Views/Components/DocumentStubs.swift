import SwiftUI

struct DocumentPicker: View {
  var onPick: ([URL]) -> Void

  init(onPick: @escaping ([URL]) -> Void) {
    self.onPick = onPick
  }

  var body: some View {
    Button("Select Documents") {
      // Mock pick
      onPick([])
    }
  }
}

struct DocumentStatusBadge: View {
  let status: DocumentStatus

  var body: some View {
    Text(status.rawValue.capitalized)
      .font(.caption2)
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(Color.gray.opacity(0.1))
      .clipShape(Capsule())
  }
}
