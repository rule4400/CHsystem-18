import CHShared
import SwiftUI
import UIKit

struct SiteCameraSettingsView: View {
  @ObservedObject var model: SiteCameraAppModel

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Label {
            Text("設定中もカメラと配信は継続しています。")
          } icon: {
            Image(systemName: "dot.radiowaves.left.and.right")
              .foregroundStyle(.green)
          }
          .font(.callout.weight(.medium))
          .accessibilityElement(children: .combine)
        }

        Section("現場情報") {
          NavigationLink {
            ConstructionNameEditView(
              currentName: model.constructionName,
              onSave: model.updateConstructionName
            )
          } label: {
            LabeledContent("工事名称") {
              Text(model.constructionName)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            }
          }
        }

        Section("配信状態") {
          LabeledContent("接続状態", value: model.effectiveConnectionStatus.displayName)
          LabeledContent(
            "本部設定の画質",
            value: model.transportSnapshot.requestedQuality.displayName
          )
          LabeledContent(
            "現在の送信画質",
            value: model.transportSnapshot.effectiveQuality.nominalVideoDescription
          )

          if let date = model.transportSnapshot.lastTransmissionAt {
            LabeledContent("最終送信") {
              Text(date, format: .dateTime.hour().minute().second())
                .monospacedDigit()
            }
          } else {
            LabeledContent("最終送信", value: "まだ送信されていません")
          }
        }

        Section("端末情報") {
          LabeledContent("端末", value: UIDevice.current.model)
          LabeledContent("iOS", value: UIDevice.current.systemVersion)
          LabeledContent("アプリ", value: appVersion)

          LabeledContent("カメラ状態") {
            Text(cameraStateDescription)
          }
        }

        #if DEBUG
          Section {
            ForEach(QualityPreset.allCases) { quality in
              Button {
                model.simulateRemoteQualityCommand(quality)
              } label: {
                HStack {
                  Text(quality.displayName)
                  Spacer()
                  Text(quality.nominalVideoDescription)
                    .foregroundStyle(.secondary)
                }
              }
            }
          } header: {
            Text("開発用：本部画質指示の模擬")
          } footer: {
            Text("この操作はDebugビルドにのみ表示され、実運用では本部から指示されます。")
          }
        #endif
      }
      .navigationTitle("設定")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("閉じる") {
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private var appVersion: String {
    let version =
      Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
      ) as? String ?? "-"
    let build =
      Bundle.main.object(
        forInfoDictionaryKey: "CFBundleVersion"
      ) as? String ?? "-"
    return "\(version) (\(build))"
  }

  private var cameraStateDescription: String {
    switch model.cameraState {
    case .idle:
      "待機中"
    case .awaitingPermission:
      "権限確認中"
    case .configuring:
      "起動中"
    case .running:
      "撮影中"
    case .permissionDenied:
      "カメラ権限がありません"
    case .unavailable:
      "利用不可"
    }
  }
}

private struct ConstructionNameEditView: View {
  let currentName: String
  let onSave: (String) -> String?

  @Environment(\.dismiss) private var dismiss
  @State private var draftName: String
  @State private var pendingValidatedName = ""
  @State private var validationMessage: String?
  @State private var isShowingConfirmation = false
  @FocusState private var isNameFieldFocused: Bool

  init(
    currentName: String,
    onSave: @escaping (String) -> String?
  ) {
    self.currentName = currentName
    self.onSave = onSave
    _draftName = State(initialValue: currentName)
  }

  var body: some View {
    Form {
      Section {
        TextField("工事名称", text: $draftName)
          .focused($isNameFieldFocused)
          .submitLabel(.done)
          .onSubmit(validateAndConfirm)

        HStack(alignment: .firstTextBaseline) {
          if let validationMessage {
            Label(validationMessage, systemImage: "exclamationmark.circle.fill")
              .font(.footnote)
              .foregroundStyle(.red)
          } else {
            Text("本部の監視画面に表示されます。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          Spacer()
          Text("\(draftName.count) / \(SiteNameValidator.maximumLength)")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(
              draftName.count > SiteNameValidator.maximumLength
                ? Color.red
                : Color.secondary
            )
        }
      } header: {
        Text("工事名称")
      } footer: {
        Text("名称を変更しても、過去の録画との関連は維持されます。設定中も配信は継続します。")
      }
    }
    .navigationTitle("工事名称を変更")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("保存") {
          validateAndConfirm()
        }
        .disabled(draftName == currentName)
      }
    }
    .onAppear {
      isNameFieldFocused = true
    }
    .onChange(of: draftName) { _, _ in
      validationMessage = nil
    }
    .alert("工事名称を変更しますか？", isPresented: $isShowingConfirmation) {
      Button("キャンセル", role: .cancel) {}
      Button("変更") {
        if let message = onSave(pendingValidatedName) {
          validationMessage = message
        } else {
          dismiss()
        }
      }
    } message: {
      Text("本部の表示名を「\(pendingValidatedName)」に変更します。")
    }
  }

  private func validateAndConfirm() {
    do {
      pendingValidatedName = try SiteNameValidator.validate(draftName)
      isShowingConfirmation = pendingValidatedName != currentName
    } catch {
      validationMessage = error.localizedDescription
    }
  }
}
