import SwiftUI

@main
@MainActor
struct SiteCameraApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var model = SiteCameraAppModel()

  var body: some Scene {
    WindowGroup {
      SiteCameraRootView(model: model)
        .preferredColorScheme(.dark)
        .task {
          await model.prepareIfNeeded()
        }
    }
    .onChange(of: scenePhase) { _, newValue in
      model.handleScenePhase(newValue)
    }
  }
}
