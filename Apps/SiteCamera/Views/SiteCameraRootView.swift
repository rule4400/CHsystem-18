import SwiftUI

struct SiteCameraRootView: View {
  @ObservedObject var model: SiteCameraAppModel

  var body: some View {
    Group {
      switch model.setupPhase {
      case .constructionName:
        ConstructionNameEntryView { name in
          model.saveInitialConstructionName(name)
        }

      case .cameraPermission:
        CameraPermissionView {
          await model.requestCameraPermissionAndBegin()
        }

      case .monitoring:
        MonitoringView(model: model)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: model.setupPhase)
  }
}
