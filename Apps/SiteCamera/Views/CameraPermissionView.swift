import SwiftUI

struct CameraPermissionView: View {
  let onRequestPermission: () async -> Void

  @State private var isRequestingPermission = false

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black, Color.blue.opacity(0.22)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 28) {
        Image(systemName: "camera.fill")
          .font(.system(size: 58, weight: .semibold))
          .foregroundStyle(.blue)
          .accessibilityHidden(true)

        VStack(spacing: 12) {
          Text("カメラを使用します")
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)

          Text("工事現場の映像を本部へ送信するため、カメラへのアクセスが必要です。")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          Label("音声は送信・録音しません", systemImage: "mic.slash.fill")
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }

        Button {
          isRequestingPermission = true
          Task {
            await onRequestPermission()
            isRequestingPermission = false
          }
        } label: {
          HStack {
            if isRequestingPermission {
              ProgressView()
                .tint(.white)
            }
            Text(
              isRequestingPermission
                ? "確認中…"
                : "カメラを許可して配信を開始"
            )
          }
          .font(.headline)
          .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRequestingPermission)
      }
      .frame(maxWidth: 560)
      .padding(32)
    }
  }
}
