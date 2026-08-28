import CHShared
import SwiftUI

struct MonitoringView: View {
  @ObservedObject var model: SiteCameraAppModel

  @State private var isShowingSettings = false

  private var status: ConnectionStatus {
    model.effectiveConnectionStatus
  }

  var body: some View {
    ZStack {
      CameraPreview(session: model.camera.captureSession)
        .ignoresSafeArea()

      if status.obscuresCameraPreview {
        Color.black.opacity(0.58)
          .ignoresSafeArea()
      }

      LinearGradient(
        colors: [Color.black.opacity(0.72), .clear, Color.black.opacity(0.82)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)

      VStack(spacing: 16) {
        topBar
        Spacer()
        statePanel
      }
      .padding(16)
    }
    .sheet(isPresented: $isShowingSettings) {
      SiteCameraSettingsView(model: model)
    }
    .persistentSystemOverlays(.hidden)
  }

  private var topBar: some View {
    HStack(spacing: 12) {
      Label(status.localizedTitle, systemImage: status.systemImage)
        .font(.headline)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(status.tint.opacity(0.9), in: Capsule())

      Text(model.constructionName)
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(.black.opacity(0.64), in: Capsule())
        .accessibilityLabel("工事名称、\(model.constructionName)")

      Spacer(minLength: 8)

      Button {
        isShowingSettings = true
      } label: {
        Image(systemName: "gearshape.fill")
          .font(.title3)
          .frame(width: 48, height: 48)
          .background(.black.opacity(0.68), in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("設定")
      .accessibilityHint("設定中もカメラと配信は継続します。")
    }
  }

  private var statePanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: status.systemImage)
          .font(.title2.weight(.semibold))
          .foregroundStyle(status.tint)
          .frame(width: 32)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(status.localizedTitle)
            .font(.title3.bold())
          Text(statusMessage)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 8)
      }

      Divider()
        .overlay(.white.opacity(0.24))

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 24) {
          qualitySummary
          lastTransmissionSummary
        }

        VStack(alignment: .leading, spacing: 10) {
          qualitySummary
          lastTransmissionSummary
        }
      }

      if model.isCameraPermissionDenied {
        Button("設定を開く") {
          model.openSystemSettings()
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("カメラへのアクセスを許可してください。")
      }
    }
    .padding(16)
    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    .frame(maxWidth: 720, alignment: .leading)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var qualitySummary: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("送信画質")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(model.transportSnapshot.effectiveQuality.nominalVideoDescription)
        .font(.callout.monospacedDigit().weight(.semibold))
      if model.transportSnapshot.requestedQuality.localizedTitle
        != model.transportSnapshot.effectiveQuality.localizedTitle
      {
        Text("本部設定：\(model.transportSnapshot.requestedQuality.localizedTitle)")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var lastTransmissionSummary: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("最終送信")
        .font(.caption)
        .foregroundStyle(.secondary)

      TimelineView(.periodic(from: .now, by: 1)) { _ in
        if let date = model.transportSnapshot.lastTransmissionAt {
          Text(date, format: .dateTime.hour().minute().second())
            .font(.callout.monospacedDigit().weight(.semibold))
        } else {
          Text("まだ送信されていません")
            .font(.callout.weight(.semibold))
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var statusMessage: String {
    if status.isCameraUnavailable, let issue = model.cameraIssueMessage {
      return issue
    }
    return status.localizedMessage
  }
}

extension ConnectionStatus {
  fileprivate var localizedTitle: String {
    switch self {
    case .connecting:
      "接続中"
    case .live:
      "配信中"
    case .reconnecting:
      "再接続中"
    case .offline:
      "本部へ送信されていません"
    case .cameraUnavailable:
      "カメラを利用できません"
    case .thermalLimited:
      "熱保護中・配信継続"
    case .thermalPaused:
      "高温のため一時停止"
    }
  }

  fileprivate var localizedMessage: String {
    switch self {
    case .connecting:
      "本部との接続を準備しています。"
    case .live:
      "本部へ映像を送信しています。"
    case .reconnecting:
      "回線を確認しています。復旧すると自動で配信を再開します。"
    case .offline:
      "切断中の映像は本部へ送信・録画されません。復旧後は自動で再接続します。"
    case .cameraUnavailable:
      "カメラの状態と権限を確認しています。"
    case .thermalLimited:
      "端末を保護するため画質を下げて配信しています。直射日光と周囲の通気を確認してください。"
    case .thermalPaused:
      "温度が下がると自動で配信を再開します。直射日光を避け、端末周辺の通気を確保してください。"
    }
  }

  fileprivate var systemImage: String {
    switch self {
    case .connecting:
      "arrow.triangle.2.circlepath"
    case .live:
      "dot.radiowaves.left.and.right"
    case .reconnecting:
      "wifi.exclamationmark"
    case .offline:
      "wifi.slash"
    case .cameraUnavailable:
      "video.slash.fill"
    case .thermalLimited:
      "thermometer.medium"
    case .thermalPaused:
      "thermometer.high"
    }
  }

  fileprivate var tint: Color {
    switch self {
    case .live:
      .green
    case .connecting:
      .blue
    case .reconnecting, .thermalLimited:
      .orange
    case .offline, .cameraUnavailable, .thermalPaused:
      .red
    }
  }

  fileprivate var obscuresCameraPreview: Bool {
    switch self {
    case .cameraUnavailable, .thermalPaused:
      true
    case .connecting, .live, .reconnecting, .offline, .thermalLimited:
      false
    }
  }

  fileprivate var isCameraUnavailable: Bool {
    if case .cameraUnavailable = self {
      true
    } else {
      false
    }
  }
}
