//
//  OpenAISettingsSheet.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import SwiftUI

struct OpenAISettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OneSceneViewModel

    @State private var apiKey = ""
    @State private var modelID = OpenAIConfiguration.defaultModelID

    var body: some View {
        NavigationStack {
            ZStack {
                OneScenePalette.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("OpenAI 設定")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(OneScenePalette.primaryText)

                            Text("撮影した写真を OpenAI の `Responses API` に送り、タイトル・キャッチコピー・ジャンルを生成します。APIキーは端末の Keychain に保存します。")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(OneScenePalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("API キー")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(OneScenePalette.primaryText)

                            SecureField("sk-...", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .background(OneScenePalette.cardFill)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("モデル")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(OneScenePalette.primaryText)

                            TextField("gpt-4.1-mini", text: $modelID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .background(OneScenePalette.cardFill)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            Text("標準は `gpt-4.1-mini` です。画像入力と Structured Outputs を使って、固定ジャンルの JSON を返します。")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(OneScenePalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("現在の状態")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(OneScenePalette.primaryText)

                            InfoChip(title: "接続", value: viewModel.isOpenAIConfigured ? "設定済み" : "未設定")
                            InfoChip(title: "保存先", value: "この端末の Keychain")
                        }

                        VStack(spacing: 12) {
                            Button {
                                let saved = viewModel.saveOpenAIConfiguration(apiKey: apiKey, modelID: modelID)
                                if saved {
                                    dismiss()
                                }
                            } label: {
                                Label("保存する", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button {
                                viewModel.clearOpenAIConfiguration()
                                apiKey = ""
                                modelID = OpenAIConfiguration.defaultModelID
                            } label: {
                                Label("設定を消す", systemImage: "trash")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }

                        Text("公開アプリとして配布する場合は、クライアントへ API キーを持たせず、サーバー経由にするのが安全です。")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(OneScenePalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(OneScenePalette.primaryText)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            apiKey = viewModel.currentOpenAIAPIKey()
            modelID = viewModel.openAIModelID
        }
    }
}
