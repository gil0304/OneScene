//
//  CaptureReviewScreen.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import SwiftUI

struct CaptureReviewScreen: View {
    @ObservedObject var viewModel: OneSceneViewModel

    var body: some View {
        ZStack {
            OneScenePalette.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        viewModel.retakePhoto()
                    } label: {
                        Label("撮り直す", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Spacer()

                    Button {
                        viewModel.returnHome()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(OneScenePalette.primaryText)
                            .padding(14)
                            .background(OneScenePalette.cardFill)
                            .clipShape(Circle())
                    }
                }

                Text("この1枚でポスターを作りますか？")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OneScenePalette.primaryText)

                Text("生成を確定するまでは撮り直しできます。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(OneScenePalette.secondaryText)

                if let previewImage = viewModel.previewImage {
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)

                            PosterPreviewGuideOverlay(imageAspectRatio: previewImage.aspectRatio)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(OneScenePalette.secondaryAccent)
                                .padding(.top, 2)

                            Text("中央の枠内は、タイトルやキャッチコピーが重ならない画像エリアです。被写体をこの中に収めるとポスター化したときに見せ場が残りやすくなります。")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(OneScenePalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        viewModel.confirmCapturedPhoto()
                    } label: {
                        Label("これで作る", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        viewModel.retakePhoto()
                    } label: {
                        Label("撮り直す", systemImage: "camera.rotate")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
    }
}
