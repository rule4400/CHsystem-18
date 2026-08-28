import SwiftUI

@main
@MainActor
struct HQMonitorApp: App {
  @StateObject private var store: HQMonitorStore

  init() {
    _store = StateObject(wrappedValue: HQMonitorStore.preview())
  }

  var body: some Scene {
    WindowGroup {
      HQMonitorRootView(store: store)
        .frame(minWidth: 1_180, minHeight: 720)
    }
    .defaultSize(width: 1_600, height: 980)
    .commands {
      CommandMenu("表示") {
        Button("監視") { store.selectedSection = .monitor }
          .keyboardShortcut("1", modifiers: .command)
        Button("録画を検索") { store.selectedSection = .recordings }
          .keyboardShortcut("2", modifiers: .command)
      }

      CommandGroup(replacing: .appSettings) {
        Button("設定…") { store.selectedSection = .settings }
          .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}
