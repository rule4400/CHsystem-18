import SwiftUI

struct ConstructionNameEntryView: View {
  let onContinue: (String) -> String?

  @State private var constructionName = ""
  @State private var validationMessage: String?
  @FocusState private var isNameFieldFocused: Bool

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black, Color.blue.opacity(0.22)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          Image(systemName: "video.fill")
            .font(.system(size: 42, weight: .semibold))
            .foregroundStyle(.blue)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 10) {
            Text("工事現場を登録")
              .font(.largeTitle.bold())
            Text("本部の監視画面に表示する工事名称を入力してください。")
              .font(.body)
              .foregroundStyle(.secondary)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("工事名称")
              .font(.headline)

            TextField("例：○○橋 上部工工事", text: $constructionName)
              .textFieldStyle(.plain)
              .font(.title3)
              .padding(.horizontal, 16)
              .frame(minHeight: 54)
              .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
              .focused($isNameFieldFocused)
              .submitLabel(.continue)
              .onSubmit(submit)
              .accessibilityHint("本部の監視画面に表示されます。")

            HStack(alignment: .firstTextBaseline) {
              if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                  .font(.footnote)
                  .foregroundStyle(.red)
              } else {
                Text("1〜80文字")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }

              Spacer()
              Text("\(constructionName.count) / 80")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(
                  constructionName.count > 80 ? Color.red : Color.secondary
                )
            }
          }

          Button(action: submit) {
            Text("次へ")
              .font(.headline)
              .frame(maxWidth: .infinity, minHeight: 52)
          }
          .buttonStyle(.borderedProminent)
          .disabled(constructionName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(maxWidth: 560)
        .padding(32)
        .frame(maxWidth: .infinity)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .onAppear {
      isNameFieldFocused = true
    }
    .onChange(of: constructionName) { _, _ in
      validationMessage = nil
    }
  }

  private func submit() {
    validationMessage = onContinue(constructionName)
  }
}
