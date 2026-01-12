import SwiftUI

extension View {
  func errorAlert(
    error: Binding<Error?>,
    retry: (() -> Void)? = nil
  ) -> some View {
    let isPresented = Binding<Bool>(
      get: { error.wrappedValue != nil },
      set: { if $0 == false { error.wrappedValue = nil } }
    )
    return self.alert(
      "Error",
      isPresented: isPresented,
      presenting: error.wrappedValue
    ) { err in
      if let retry = retry {
        Button("Try Again", action: retry)
      }
      Button("OK", role: .cancel) { error.wrappedValue = nil }
    } message: { err in
      Text(err.localizedDescription)
    }
  }
}
