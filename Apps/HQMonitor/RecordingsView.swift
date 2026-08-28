import Combine
import SwiftUI

struct RecordingsView: View {
  @ObservedObject var store: HQMonitorStore
  @State private var searchText = ""
  @State private var missingOnly = false
  @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
  @State private var endDate = Date.now

  private var filteredRecordings: [RecordingPresentation] {
    store.recordings.filter { recording in
      let nameMatches =
        searchText.isEmpty || recording.siteName.localizedStandardContains(searchText)
      let gapMatches = !missingOnly || !recording.gaps.isEmpty
      let rangeMatches =
        recording.endedAt >= startDate && recording.startedAt <= endDate.addingTimeInterval(86_400)
      return nameMatches && gapMatches && rangeMatches
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      searchControls
      Divider()

      HSplitView {
        recordingList
          .frame(minWidth: 310, idealWidth: 360, maxWidth: 460)

        Group {
          if let recording = store.selectedRecording {
            RecordingPlaybackView(recording: recording)
              .id(recording.id)
          } else {
            ContentUnavailableView(
              "録画を選択してください",
              systemImage: "play.rectangle",
              description: Text("左の一覧から録画を選ぶと、映像と欠落区間を確認できます。")
            )
          }
        }
        .frame(minWidth: 580, maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private var searchControls: some View {
    HStack(spacing: 12) {
      TextField("工事名称を検索", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .frame(minWidth: 200, idealWidth: 280, maxWidth: 360)

      DatePicker("開始", selection: $startDate, displayedComponents: .date)
        .labelsHidden()
        .accessibilityLabel("検索開始日")

      Text("〜")
        .foregroundStyle(.secondary)

      DatePicker("終了", selection: $endDate, displayedComponents: .date)
        .labelsHidden()
        .accessibilityLabel("検索終了日")

      Toggle("欠落ありのみ", isOn: $missingOnly)
        .toggleStyle(.checkbox)

      Spacer()

      Text("\(filteredRecordings.count)件")
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .padding(12)
  }

  private var recordingList: some View {
    List(filteredRecordings, selection: $store.selectedRecordingID) { recording in
      RecordingRow(recording: recording)
        .tag(recording.id)
    }
    .overlay {
      if filteredRecordings.isEmpty {
        ContentUnavailableView.search(text: searchText)
      }
    }
    .accessibilityLabel("録画検索結果")
  }
}

private struct RecordingRow: View {
  let recording: RecordingPresentation

  var body: some View {
    HStack(spacing: 10) {
      CameraBackdrop(seed: recording.backgroundSeed)
        .frame(width: 96, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .bottomTrailing) {
          if !recording.gaps.isEmpty {
            Label("欠落", systemImage: "exclamationmark.triangle.fill")
              .labelStyle(.iconOnly)
              .foregroundStyle(.yellow)
              .padding(4)
              .background(.black.opacity(0.7), in: Circle())
              .padding(4)
          }
        }

      VStack(alignment: .leading, spacing: 4) {
        Text(recording.siteName)
          .font(.headline)
          .lineLimit(1)
        Text("\(recording.startedAt.formattedJST)〜\(recording.endedAt.formattedJSTTime)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        HStack(spacing: 8) {
          Text(recording.quality.compactName)
          Text("収録 \(recording.coverage.formatted(.percent.precision(.fractionLength(1))))")
          if !recording.gaps.isEmpty {
            Label(
              Self.durationLabel(recording.missingDuration),
              systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
          }
        }
        .font(.caption2)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(recording.siteName)、\(recording.startedAt.formattedJST)から\(recording.endedAt.formattedJSTTime)、画質\(recording.quality.compactName)、収録率\(recording.coverage.formatted(.percent))、欠落\(Self.durationLabel(recording.missingDuration))"
    )
  }

  private static func durationLabel(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration))
    if seconds >= 60 {
      return "欠落 \(seconds / 60)分\(seconds % 60)秒"
    }
    return "欠落 \(seconds)秒"
  }
}

private struct RecordingPlaybackView: View {
  let recording: RecordingPresentation
  @State private var playhead: TimeInterval = 0
  @State private var isPlaying = false
  @State private var playbackRate = 1.0

  private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  private var playbackDate: Date {
    recording.startedAt.addingTimeInterval(playhead)
  }

  private var activeGap: GapPresentation? {
    recording.gaps.first { playbackDate >= $0.startedAt && playbackDate < $0.endedAt }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text(recording.siteName)
              .font(.title2.weight(.semibold))
            Text("\(recording.startedAt.formattedJST)〜\(recording.endedAt.formattedJST)")
              .font(.callout.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 3) {
            Text("収録率 \(recording.coverage.formatted(.percent.precision(.fractionLength(1))))")
              .font(.headline)
            Text("保存期限 \(recording.expiresAt.formattedJST)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        ZStack {
          CameraBackdrop(seed: recording.backgroundSeed)
          Color.black.opacity(activeGap == nil ? 0.04 : 0.82)

          if let activeGap {
            VStack(spacing: 8) {
              Image(systemName: "wifi.slash")
                .font(.largeTitle)
              Text("この区間には映像がありません")
                .font(.title3.weight(.semibold))
              Text("\(activeGap.reason)：\(Self.durationLabel(activeGap.duration))")
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 12))
          }

          VStack {
            Spacer()
            HStack(alignment: .lastTextBaseline) {
              Text(recording.siteName)
                .lineLimit(1)
              Spacer()
              Text(playbackDate.formattedJST)
                .font(.body.monospacedDigit())
            }
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(14)
            .background(
              LinearGradient(
                colors: [.clear, .black.opacity(0.84)], startPoint: .top, endPoint: .bottom)
            )
          }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          activeGap == nil
            ? "録画映像、撮影時刻\(playbackDate.formattedJST)"
            : "映像なし、\(activeGap?.reason ?? "通信断")、撮影時刻\(playbackDate.formattedJST)")

        PlaybackTimeline(recording: recording, playhead: $playhead)

        HStack(spacing: 12) {
          Button {
            if playhead >= recording.duration { playhead = 0 }
            isPlaying.toggle()
          } label: {
            Label(isPlaying ? "一時停止" : "再生", systemImage: isPlaying ? "pause.fill" : "play.fill")
          }
          .buttonStyle(.borderedProminent)

          Slider(value: $playhead, in: 0...recording.duration)
            .accessibilityLabel("再生位置")
            .accessibilityValue(playbackDate.formattedJST)

          Text(playbackDate.formattedJSTTime)
            .font(.callout.monospacedDigit())
            .frame(width: 72, alignment: .trailing)

          Picker("速度", selection: $playbackRate) {
            Text("0.5×").tag(0.5)
            Text("1×").tag(1.0)
            Text("2×").tag(2.0)
            Text("4×").tag(4.0)
          }
          .frame(width: 88)
        }

        HStack(spacing: 20) {
          Label("画質 \(recording.quality.monitorDisplayName)", systemImage: "rectangle.inset.filled")
          Label(
            "欠落 \(Self.durationLabel(recording.missingDuration))",
            systemImage: "exclamationmark.triangle")
          Label(recording.fileSizeBytes.formattedStorage, systemImage: "internaldrive")
          Label("音声なし", systemImage: "speaker.slash")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
      }
      .padding(18)
    }
    .onReceive(ticker) { _ in
      guard isPlaying else { return }
      playhead = min(recording.duration, playhead + playbackRate)
      if playhead >= recording.duration { isPlaying = false }
    }
  }

  private static func durationLabel(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration))
    if seconds >= 60 {
      return "\(seconds / 60)分\(seconds % 60)秒"
    }
    return "\(seconds)秒"
  }
}

private struct PlaybackTimeline: View {
  let recording: RecordingPresentation
  @Binding var playhead: TimeInterval

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 5)
            .fill(Color.accentColor.opacity(0.55))

          ForEach(recording.gaps) { gap in
            let start = max(0, gap.startedAt.timeIntervalSince(recording.startedAt))
            let fraction = start / recording.duration
            let widthFraction = max(0.004, gap.duration / recording.duration)
            Rectangle()
              .fill(.orange)
              .overlay {
                Image(systemName: "line.diagonal")
                  .resizable(resizingMode: .tile)
                  .foregroundStyle(.black.opacity(0.34))
              }
              .frame(width: proxy.size.width * widthFraction)
              .offset(x: proxy.size.width * fraction)
              .help(
                "\(gap.reason)：\(gap.startedAt.formattedJSTTime)〜\(gap.endedAt.formattedJSTTime)")
          }

          Rectangle()
            .fill(.white)
            .frame(width: 2)
            .shadow(color: .black, radius: 2)
            .offset(x: proxy.size.width * (playhead / recording.duration))
        }
      }
      .frame(height: 24)
      .clipShape(RoundedRectangle(cornerRadius: 5))

      HStack {
        Label("録画あり", systemImage: "rectangle.fill")
          .foregroundStyle(Color.accentColor)
        Label("欠落区間", systemImage: "rectangle.fill")
          .foregroundStyle(.orange)
        Spacer()
        Text("欠落区間は実時間のまま表示します")
          .foregroundStyle(.secondary)
      }
      .font(.caption)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "録画タイムライン。欠落区間\(recording.gaps.count)件、合計\(Int(recording.missingDuration))秒。")
  }
}

#Preview("録画検索") {
  RecordingsView(store: .preview())
    .frame(width: 1_450, height: 880)
}
