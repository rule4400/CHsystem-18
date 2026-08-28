import CHShared
import SwiftUI

struct MonitorView: View {
  @ObservedObject var store: HQMonitorStore

  private var inspectorPresented: Binding<Bool> {
    Binding(
      get: { store.selectedSiteID != nil },
      set: { isPresented in
        if !isPresented { store.selectedSiteID = nil }
      }
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      MonitorSummaryBar(store: store)
      Divider()
      MonitorCanvas(store: store)
    }
    .background(Color.black.opacity(0.94))
    .inspector(isPresented: inspectorPresented) {
      if let site = store.selectedSite {
        SiteInspectorView(store: store, site: site)
          .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
      }
    }
  }
}

private struct MonitorSummaryBar: View {
  @ObservedObject var store: HQMonitorStore

  var body: some View {
    HStack(spacing: 16) {
      Label("接続 \(store.onlineCount)/\(store.sites.count)", systemImage: "network")
        .foregroundStyle(.primary)
      Label("録画中 \(store.recordingCount)", systemImage: "record.circle.fill")
        .foregroundStyle(.red)
      if store.attentionCount > 0 {
        Label("要確認 \(store.attentionCount)", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
      }
      Spacer()
      Text("表示 \(store.tileCount)画面")
      Text("時刻：JST")
    }
    .font(.callout.weight(.medium))
    .padding(.horizontal, 14)
    .frame(height: 38)
    .foregroundStyle(.white)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    .accessibilityElement(children: .combine)
  }
}

private struct MonitorCanvas: View {
  @ObservedObject var store: HQMonitorStore

  private var side: Int { Int(Double(store.tileCount).squareRoot()) }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { timeline in
      GeometryReader { proxy in
        if let expanded = store.expandedSite {
          expandedView(expanded, at: timeline.date, in: proxy.size)
        } else {
          grid(at: timeline.date, in: proxy.size)
        }
      }
    }
    .focusable()
    .onMoveCommand { direction in
      store.moveSelection(direction, columns: side)
    }
    .onKeyPress(.return) {
      guard let selectedSiteID = store.selectedSiteID else { return .ignored }
      store.expand(selectedSiteID)
      return .handled
    }
    .onExitCommand {
      if store.expandedSiteID != nil {
        store.closeExpandedSite()
      } else {
        store.selectedSiteID = nil
      }
    }
  }

  private func grid(at date: Date, in size: CGSize) -> some View {
    let spacing: CGFloat = 4
    let columns = max(1, side)
    let rows = columns
    let availableWidth = max(1, size.width - spacing * CGFloat(columns - 1))
    let availableHeight = max(1, size.height - spacing * CGFloat(rows - 1))
    let widthConstrained = availableWidth / CGFloat(columns)
    let heightConstrained = (availableHeight / CGFloat(rows)) * 16 / 9
    let tileWidth = max(1, min(widthConstrained, heightConstrained))
    let tileHeight = tileWidth * 9 / 16
    let gridWidth = tileWidth * CGFloat(columns) + spacing * CGFloat(columns - 1)
    let gridHeight = tileHeight * CGFloat(rows) + spacing * CGFloat(rows - 1)
    let layout = Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: columns)

    return LazyVGrid(columns: layout, alignment: .center, spacing: spacing) {
      ForEach(store.visibleSites) { site in
        SiteTileView(
          site: site,
          now: date,
          isSelected: store.selectedSiteID == site.id,
          onSelect: { store.select(site.id) },
          onExpand: { store.expand(site.id) }
        )
        .frame(width: tileWidth, height: tileHeight)
      }
    }
    .frame(width: gridWidth, height: gridHeight)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func expandedView(_ site: SitePresentation, at date: Date, in size: CGSize) -> some View {
    let width = min(size.width, size.height * 16 / 9)
    let height = width * 9 / 16

    return ZStack(alignment: .topLeading) {
      SiteTileView(
        site: site,
        now: date,
        isSelected: true,
        onSelect: {},
        onExpand: {}
      )
      .frame(width: width, height: height)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Button {
        store.closeExpandedSite()
      } label: {
        Label("一覧へ戻る", systemImage: "arrow.backward")
      }
      .buttonStyle(.borderedProminent)
      .padding(16)
      .keyboardShortcut(.escape, modifiers: [])
    }
  }
}

private struct SiteTileView: View {
  let site: SitePresentation
  let now: Date
  let isSelected: Bool
  let onSelect: () -> Void
  let onExpand: () -> Void

  private var captureDate: Date { site.captureDate(at: now) }

  var body: some View {
    Button(action: onSelect) {
      ZStack {
        CameraBackdrop(seed: site.backgroundSeed)

        if !site.connectionState.isReceivingFrames {
          Color.black.opacity(0.58)
          inactiveOverlay
        } else if case .thermalLimited = site.connectionState {
          Color.orange.opacity(0.08)
        }

        VStack(spacing: 0) {
          topOverlay
          Spacer(minLength: 4)
          bottomOverlay
        }
      }
      .aspectRatio(16 / 9, contentMode: .fit)
      .clipped()
      .overlay {
        Rectangle()
          .strokeBorder(
            isSelected ? Color.accentColor : Color.white.opacity(0.12),
            lineWidth: isSelected ? 3 : 1)
      }
    }
    .buttonStyle(.plain)
    .simultaneousGesture(TapGesture(count: 2).onEnded(onExpand))
    .contextMenu {
      Button("拡大表示", action: onExpand)
    }
    .help(site.name)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(named: "拡大表示", onExpand)
  }

  private var topOverlay: some View {
    HStack(alignment: .top, spacing: 6) {
      StatusBadge(
        icon: site.connectionState.icon,
        text: site.connectionState.label(at: now),
        tint: site.connectionState.tint
      )

      if site.connectionState.isReceivingFrames {
        Text(site.measuredQuality?.compactName ?? "—")
          .font(.caption2.monospacedDigit().weight(.semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 4)
          .background(.black.opacity(0.72), in: Capsule())
          .foregroundStyle(.white)
      }

      Spacer(minLength: 2)

      StatusBadge(
        icon: site.recordingState.icon,
        text: site.recordingState.label(at: now),
        tint: site.recordingState.tint
      )
    }
    .lineLimit(1)
    .minimumScaleFactor(0.72)
    .padding(7)
  }

  private var bottomOverlay: some View {
    HStack(alignment: .lastTextBaseline, spacing: 8) {
      Text(site.name)
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(captureDate.formattedJST)
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }
    .foregroundStyle(.white)
    .shadow(color: .black, radius: 2, y: 1)
    .padding(.horizontal, 8)
    .padding(.top, 24)
    .padding(.bottom, 7)
    .background(
      LinearGradient(
        colors: [.clear, .black.opacity(0.82)],
        startPoint: .top,
        endPoint: .bottom
      )
    )
  }

  @ViewBuilder
  private var inactiveOverlay: some View {
    VStack(spacing: 5) {
      Image(systemName: site.connectionState.icon)
        .font(.title2.weight(.semibold))
      Text(site.connectionState.label(at: now))
        .font(.headline)
      Text("最終受信 \(site.frozenCaptureDate.formattedJST)")
        .font(.caption.monospacedDigit())
    }
    .foregroundStyle(.white)
    .padding(12)
    .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 8))
    .accessibilityHidden(true)
  }

  private var accessibilityLabel: String {
    "\(site.name)、\(site.connectionState.label(at: now))、\(site.recordingState.label(at: now))、実効画質\(site.measuredQuality?.compactName ?? "不明")、撮影時刻\(captureDate.formattedJST)、日本標準時"
  }
}

private struct StatusBadge: View {
  let icon: String
  let text: String
  let tint: Color

  var body: some View {
    Label(text, systemImage: icon)
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(.black.opacity(0.76), in: Capsule())
      .overlay(alignment: .leading) {
        Circle()
          .fill(tint)
          .frame(width: 6, height: 6)
          .offset(x: 5)
          .accessibilityHidden(true)
      }
  }
}

struct CameraBackdrop: View {
  let seed: Int

  private var hue: Double { Double((seed * 37 + 204) % 360) / 360 }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        LinearGradient(
          colors: [
            Color(hue: hue, saturation: 0.34, brightness: 0.42),
            Color(hue: hue + 0.06, saturation: 0.48, brightness: 0.18),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        Path { path in
          let horizon = proxy.size.height * 0.63
          path.move(to: CGPoint(x: 0, y: horizon))
          path.addLine(to: CGPoint(x: proxy.size.width, y: horizon * 0.9))
          path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
          path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
          path.closeSubpath()
        }
        .fill(Color.black.opacity(0.28))

        Image(systemName: seed.isMultiple(of: 2) ? "building.2.fill" : "road.lanes")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.white.opacity(0.2))
          .frame(width: proxy.size.width * 0.36, height: proxy.size.height * 0.42)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct SiteInspectorView: View {
  @ObservedObject var store: HQMonitorStore
  let site: SitePresentation
  @State private var confirmsStop = false

  private let qualityOptions: [QualityPreset] = [.low, .standard, .high]

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { timeline in
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 5) {
            Text(site.name)
              .font(.title3.weight(.semibold))
              .textSelection(.enabled)
            Label(
              site.connectionState.label(at: timeline.date),
              systemImage: site.connectionState.icon
            )
            .foregroundStyle(site.connectionState.tint)
          }

          InspectorSection("映像・通信") {
            InspectorRow("希望画質", site.desiredQuality.monitorDisplayName)
            InspectorRow("端末適用", site.appliedQuality?.monitorDisplayName ?? "応答待ち")
            InspectorRow("実測受信", measuredDescription)
            InspectorRow("ビットレート", "\(site.bitrateKbps) kbps")
            InspectorRow("遅延", String(format: "%.1f秒", site.networkLatency))
            InspectorRow("端末温度", site.thermalDescription)
            InspectorRow("最終受信", site.captureDate(at: timeline.date).formattedJST)
          }

          VStack(alignment: .leading, spacing: 8) {
            Picker(
              "希望画質",
              selection: Binding(
                get: { site.desiredQuality },
                set: { store.requestQuality($0, for: site.id) }
              )
            ) {
              ForEach(qualityOptions, id: \.self) { quality in
                Text(quality.monitorDisplayName).tag(quality)
              }
            }

            if let commandLabel = site.qualityCommandState.label {
              HStack(alignment: .firstTextBaseline, spacing: 7) {
                if case .sending = site.qualityCommandState {
                  ProgressView().controlSize(.small)
                } else {
                  Image(systemName: commandStateIcon)
                }
                Text(commandLabel)
                  .font(.caption)
              }
              .foregroundStyle(commandStateTint)
              .accessibilityElement(children: .combine)
            }
          }

          Divider()

          InspectorSection("録画") {
            InspectorRow("状態", site.recordingState.label(at: timeline.date))
          }

          recordingButton

          Text("この画面を閉じても、中央サーバーで録画は継続します。")
            .font(.caption)
            .foregroundStyle(.secondary)

          Button("この現場の録画を見る") {
            store.showRecordings(for: site.id)
          }
          .buttonStyle(.link)
        }
        .padding(18)
      }
    }
    .navigationTitle("現場詳細")
    .confirmationDialog(
      "「\(site.name)」の録画を停止しますか？",
      isPresented: $confirmsStop,
      titleVisibility: .visible
    ) {
      Button("録画を停止", role: .destructive) {
        store.stopRecording(for: site.id)
      }
      Button("キャンセル", role: .cancel) {}
    } message: {
      Text("停止が中央サーバーで確認されるまで、表示は「録画停止中」のままです。")
    }
  }

  private var measuredDescription: String {
    let resolution: String
    switch site.measuredQuality {
    case .low: resolution = "640×360"
    case .standard: resolution = "1280×720"
    case .high: resolution = "1920×1080"
    case .none: resolution = "—"
    @unknown default: resolution = "—"
    }
    return
      "\(resolution) / \(site.framesPerSecond.formatted(.number.precision(.fractionLength(1)))) fps"
  }

  @ViewBuilder
  private var recordingButton: some View {
    switch site.recordingState {
    case .idle, .failed, .interrupted:
      Button("録画を開始") { store.startRecording(for: site.id) }
        .buttonStyle(.borderedProminent)
    case .recording:
      Button("録画を停止…", role: .destructive) { confirmsStop = true }
        .buttonStyle(.bordered)
    case .starting, .stopping:
      HStack {
        ProgressView().controlSize(.small)
        Text(site.recordingState.label(at: .now))
      }
      .foregroundStyle(.secondary)
    }
  }

  private var commandStateIcon: String {
    switch site.qualityCommandState {
    case .applied: "checkmark.circle.fill"
    case .queued: "clock.badge.exclamationmark"
    case .idle, .sending: "circle"
    }
  }

  private var commandStateTint: Color {
    switch site.qualityCommandState {
    case .applied: .green
    case .queued: .orange
    case .idle, .sending: .secondary
    }
  }
}

private struct InspectorSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(title)
        .font(.headline)
      content
    }
  }
}

private struct InspectorRow: View {
  let label: String
  let value: String

  init(_ label: String, _ value: String) {
    self.label = label
    self.value = value
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      Text(value)
        .multilineTextAlignment(.trailing)
        .textSelection(.enabled)
    }
    .font(.callout)
    .accessibilityElement(children: .combine)
  }
}

#Preview("25画面監視") {
  MonitorView(store: .preview())
    .frame(width: 1_500, height: 900)
}
