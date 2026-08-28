import AppKit
import SwiftUI

struct HQMonitorRootView: View {
  @ObservedObject var store: HQMonitorStore

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
    } detail: {
      Group {
        switch store.selectedSection {
        case .monitor:
          MonitorView(store: store)
        case .recordings:
          RecordingsView(store: store)
        case .settings:
          RecordingSettingsView(store: store)
        }
      }
      .navigationTitle(store.selectedSection.title)
    }
    .navigationSplitViewStyle(.balanced)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        if store.selectedSection == .monitor {
          Picker("表示数", selection: $store.tileCount) {
            ForEach(store.tileOptions, id: \.self) { count in
              Text("\(count)画面").tag(count)
            }
          }
          .pickerStyle(.menu)
          .help("一度に表示する現場数を変更します")
          .accessibilityLabel("表示するタイル数")
        }

        Button {
          NSApp.keyWindow?.toggleFullScreen(nil)
        } label: {
          Label("全画面", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .help("監視画面を全画面で表示します")
      }
    }
  }

  private var sidebar: some View {
    VStack(spacing: 0) {
      List(selection: $store.selectedSection) {
        Section("本部モニター") {
          ForEach(HQSection.allCases) { section in
            Label(section.title, systemImage: section.systemImage)
              .tag(section)
          }
        }
      }
      .listStyle(.sidebar)

      Divider()

      VStack(alignment: .leading, spacing: 8) {
        Label("接続 \(store.onlineCount)/\(store.sites.count)", systemImage: "network")
        Label("録画中 \(store.recordingCount)", systemImage: "record.circle")
        Label("要確認 \(store.attentionCount)", systemImage: "exclamationmark.triangle")
          .foregroundStyle(
            Color(nsColor: store.attentionCount == 0 ? .secondaryLabelColor : .systemOrange))
        Text("時刻表示：JST")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .font(.callout)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "全体状態。接続 \(store.onlineCount)件、全\(store.sites.count)件。録画中 \(store.recordingCount)件。要確認 \(store.attentionCount)件。時刻は日本標準時。"
      )
    }
  }
}

#Preview("本部モニター") {
  HQMonitorRootView(store: .preview())
    .frame(width: 1_600, height: 980)
}
