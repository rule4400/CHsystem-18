import SwiftUI

struct RecordingSettingsView: View {
  @ObservedObject var store: HQMonitorStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        settingsHeader
        recordingCard
        retentionCard
        storageCard
        operatingPolicyCard

        HStack {
          if let settingsMessage = store.settingsMessage {
            Label(settingsMessage, systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .accessibilityLabel(settingsMessage)
          }
          Spacer()
          Button("設定を保存") {
            store.prepareRetentionSave()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        }
      }
      .frame(maxWidth: 820, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .sheet(item: $store.pendingRetentionImpact) { impact in
      RetentionImpactSheet(store: store, impact: impact)
    }
  }

  private var settingsHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("録画・保存設定")
        .font(.largeTitle.weight(.semibold))
      Text("既定の録画動作と、中央サーバーに保存する日数を設定します。")
        .foregroundStyle(.secondary)
    }
  }

  private var recordingCard: some View {
    SettingsCard("既定の録画動作", systemImage: "record.circle") {
      Picker("新しい現場の既定", selection: $store.draftRecordingPolicy) {
        ForEach(RecordingPolicy.allCases) { policy in
          Text(policy.label).tag(policy)
        }
      }
      .pickerStyle(.segmented)

      Text(recordingPolicyHelp)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var retentionCard: some View {
    SettingsCard("保存期間", systemImage: "calendar.badge.clock") {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        TextField("日数", value: $store.draftRetentionDays, format: .number)
          .textFieldStyle(.roundedBorder)
          .frame(width: 90)
          .multilineTextAlignment(.trailing)
          .accessibilityLabel("保存日数")

        Text("日")

        Stepper(
          "",
          value: $store.draftRetentionDays,
          in: 1...3_650
        )
        .labelsHidden()

        Spacer()

        Text("設定可能範囲：1〜3650日")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if store.draftRetentionDays < store.retentionDays {
        Label(
          "現在の\(store.retentionDays)日より短くするため、保存前に削除対象を確認します。",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.callout)
        .foregroundStyle(.orange)
      }

      Divider()

      VStack(alignment: .leading, spacing: 8) {
        Text("現場別の上書き")
          .font(.headline)
        SiteRetentionRow(name: "国道18号 上田バイパス工事", value: "90日")
        SiteRetentionRow(name: "中央橋耐震補強工事", value: "既定値（\(store.draftRetentionDays)日）")
        SiteRetentionRow(name: "港湾第3埠頭改良工事", value: "60日")
        Button("現場別設定を管理…") {}
          .buttonStyle(.link)
          .disabled(true)
          .help("現場別保存期間は次の実装段階で編集可能にします")
      }
    }
  }

  private var storageCard: some View {
    SettingsCard("ストレージ", systemImage: "internaldrive") {
      ProgressView(value: store.storageFraction)
        .tint(
          store.storageFraction >= 0.9
            ? .red : store.storageFraction >= 0.8 ? .orange : .accentColor
        )
        .accessibilityLabel("ストレージ使用率")
        .accessibilityValue(store.storageFraction.formatted(.percent))

      HStack {
        Text("使用中 \(store.storageUsedBytes.formattedStorage)")
        Spacer()
        Text("総容量 \(store.storageCapacityBytes.formattedStorage)")
      }
      .font(.callout.monospacedDigit())

      Label(
        "残り約 \((store.storageCapacityBytes - store.storageUsedBytes).formattedStorage)。現在の条件で約13日分です。",
        systemImage: "info.circle"
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
  }

  private var operatingPolicyCard: some View {
    SettingsCard("欠落・容量不足時の動作", systemImage: "shield.lefthalf.filled") {
      SettingsValueRow(label: "回線断中", value: "欠落を許容・端末保存なし")
      SettingsValueRow(label: "容量20%未満", value: "警告を表示")
      SettingsValueRow(label: "容量10%未満", value: "重大警告を表示")
      SettingsValueRow(label: "安全下限到達", value: "新規録画を停止して通知")

      Text("回線断中の映像は本部へ送信・録画されません。復旧後の録画には欠落区間が明示されます。")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var recordingPolicyHelp: String {
    switch store.draftRecordingPolicy {
    case .manual:
      "オペレーターが現場ごとに録画を開始します。"
    case .continuous:
      "現場がオンラインになると、中央サーバーで自動的に録画を開始します。"
    case .off:
      "ライブ監視のみ行い、既定では録画しません。"
    }
  }
}

private struct SettingsCard<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: Content

  init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: systemImage)
        .font(.title3.weight(.semibold))
      content
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.separator.opacity(0.6))
    }
  }
}

private struct SiteRetentionRow: View {
  let name: String
  let value: String

  var body: some View {
    HStack {
      Text(name).lineLimit(1)
      Spacer()
      Text(value)
        .foregroundStyle(.secondary)
    }
    .font(.callout)
    .accessibilityElement(children: .combine)
  }
}

private struct SettingsValueRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .multilineTextAlignment(.trailing)
    }
    .font(.callout)
    .accessibilityElement(children: .combine)
  }
}

private struct RetentionImpactSheet: View {
  @ObservedObject var store: HQMonitorStore
  let impact: RetentionImpact

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Label("保存期間を短縮します", systemImage: "exclamationmark.triangle.fill")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.orange)

      Text("保存期間を\(impact.oldDays)日から\(impact.newDays)日に変更します。")
        .font(.headline)

      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
        ImpactRow(label: "削除対象", value: "\(impact.affectedCount.formatted())件")
        ImpactRow(label: "推定容量", value: impact.estimatedBytes.formattedStorage)
        ImpactRow(
          label: "対象期間", value: "\(impact.rangeStart.formattedJST)〜\(impact.rangeEnd.formattedJST)")
        ImpactRow(label: "削除開始", value: "\(impact.deletionStartsAt.formattedJST) JST")
      }

      Text("削除後は復元できません。削除処理は変更後24時間以内に開始されます。")
        .font(.callout.weight(.semibold))
        .foregroundStyle(.red)

      HStack {
        Spacer()
        Button("キャンセル") {
          store.cancelRetentionChange()
        }
        .keyboardShortcut(.cancelAction)

        Button("保存期間を\(impact.newDays)日に変更", role: .destructive) {
          store.confirmRetentionChange()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(26)
    .frame(width: 590)
    .interactiveDismissDisabled()
    .accessibilityElement(children: .contain)
  }
}

private struct ImpactRow: View {
  let label: String
  let value: String

  var body: some View {
    GridRow {
      Text(label)
        .foregroundStyle(.secondary)
      Text(value)
        .textSelection(.enabled)
    }
  }
}

#Preview("録画・保存設定") {
  RecordingSettingsView(store: .preview())
    .frame(width: 1_100, height: 900)
}
