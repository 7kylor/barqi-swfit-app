import SwiftData
import SwiftUI

@main
struct BarQiApp: App {
  @State private var appModel: AppModel?

  var body: some Scene {
    WindowGroup {
      if let appModel {
        ContentView()
          .environment(appModel)
          .environment(LocalizationManager.shared)
          .modelContainer(appModel.modelContainer)
      } else {
        ProgressView("Initializing BarQi...")
          .task {
            await initializeApp()
          }
      }
    }
  }

  private func initializeApp() async {
    let schema = Schema([
      Conversation.self,
      ChatMessage.self,
      AIModel.self,
      LanguagePreference.self,
    ])

    let config = ModelConfiguration(isStoredInMemoryOnly: false)

    do {
      let container = try ModelContainer(for: schema, configurations: config)
      let model = AppModel(modelContainer: container)
      await MainActor.run {
        self.appModel = model
      }
    } catch {
      print("Failed to create ModelContainer: \(error)")
    }
  }
}
