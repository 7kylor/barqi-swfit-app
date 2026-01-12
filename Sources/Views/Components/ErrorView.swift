
import SwiftUI

// MARK: - Alert Modifier

extension View {
    func errorAlert(
        error: Binding<Error?>,
        retry: (() -> Void)? = nil,
        model: AIModel? = nil,
        appModel: AppModel? = nil
    ) -> some View {
        let isPresented = Binding<Bool>(
            get: { error.wrappedValue != nil },
            set: { if $0 == false { error.wrappedValue = nil } }
        )
        return self.alert(
            L("error"),
            isPresented: isPresented,
            presenting: error.wrappedValue
        ) { err in
            if let retry = retry {
                Button(L("try_again"), action: retry)
            }
            Button(L("send_diagnostics")) {
                if let error = error.wrappedValue {
                    Task { @MainActor in
                        await DiagnosticsCollector.sendDiagnosticsEmail(
                            error: error,
                            model: model,
                            appModel: appModel
                        )
                    }
                }
            }
            Button(L("ok"), role: .cancel) { error.wrappedValue = nil }
        } message: { err in
            Text(err.localizedDescription)
        }
    }
}
