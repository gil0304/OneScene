//
//  ContentView.swift
//  OneScene
//
//  Created by 落合遼梧 on 2026/04/22.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = OneSceneViewModel()

    var body: some View {
        ZStack {
            OneScenePalette.backgroundGradient
                .ignoresSafeArea()

            currentScreen
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            OpenAISettingsSheet(viewModel: viewModel)
        }
        .overlay(alignment: .top) {
            if let toastMessage = viewModel.toastMessage {
                ToastPill(message: toastMessage)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: viewModel.screen)
        .animation(.easeInOut(duration: 0.25), value: viewModel.toastMessage)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch viewModel.screen {
        case .home:
            HomeScreen(viewModel: viewModel)
        case .camera:
            CameraScreen(viewModel: viewModel)
        case .review:
            CaptureReviewScreen(viewModel: viewModel)
        case .generating:
            GeneratingScreen(message: viewModel.generationMessage)
        case .result:
            ResultScreen(viewModel: viewModel)
        }
    }
}

private struct HomeScreen: View {
    @ObservedObject var viewModel: OneSceneViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OneScene")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(OneScenePalette.primaryText)

                        Text("今日、その場で撮った1枚を映画にする。")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(OneScenePalette.primaryText)

                        Text("日常の一瞬を、その日の作品として残すためのポスター生成アプリ。写真はアプリ内カメラで撮影した1枚だけを使います。")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(OneScenePalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 18)

                    RoundIconButton(systemName: "key.fill") {
                        viewModel.presentSettings()
                    }
                }

                statusCard

                LazyVGrid(columns: columns, spacing: 12) {
                    InfoChip(title: "撮影手段", value: "アプリ内カメラのみ")
                    InfoChip(title: "今日の回数", value: viewModel.hasGeneratedToday ? "生成済み" : "未生成")
                    InfoChip(title: "AI生成", value: viewModel.openAIStatusText)
                    InfoChip(title: "モデル", value: viewModel.openAIModelID)
                }

                if let latestPoster = viewModel.latestPoster,
                   let latestRecord = viewModel.latestRecord {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("前回の作品")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(OneScenePalette.primaryText)

                            Spacer()

                            GenreBadge(genre: latestRecord.story.genre)
                        }

                        Image(uiImage: latestPoster)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.28), radius: 30, y: 18)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(latestRecord.story.title)
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundStyle(OneScenePalette.primaryText)

                            Text(latestRecord.story.tagline)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(OneScenePalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(18)
                    .background(OneScenePalette.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

                VStack(spacing: 12) {
                    Button {
                        viewModel.startCaptureFlow()
                    } label: {
                        Label(viewModel.hasGeneratedToday ? "今日は生成済みです" : "今日の1枚を撮る", systemImage: "camera.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.hasGeneratedToday)

                    Button {
                        viewModel.openLatestResult()
                    } label: {
                        Label("前回の作品を見る", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!viewModel.canViewLatestWork)
                    .opacity(viewModel.canViewLatestWork ? 1 : 0.55)

                    Button {
                        viewModel.presentSettings()
                    } label: {
                        Label(viewModel.isOpenAIConfigured ? "AI設定を開く" : "OpenAIキーを設定", systemImage: "key.horizontal.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(viewModel.hasGeneratedToday ? OneScenePalette.warning : OneScenePalette.accent)
                    .frame(width: 10, height: 10)

                Text(viewModel.todayStatusText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(OneScenePalette.primaryText)
            }

            Text(viewModel.statusDetailText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(OneScenePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack {
                Label(viewModel.openAIStatusText, systemImage: viewModel.isOpenAIConfigured ? "checkmark.seal.fill" : "key.slash.fill")
                Spacer()
                Text(viewModel.openAIModelID)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(OneScenePalette.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            OneScenePalette.cardBase,
                            viewModel.hasGeneratedToday ? OneScenePalette.warning.opacity(0.2) : OneScenePalette.accent.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct CameraScreen: View {
    @ObservedObject var viewModel: OneSceneViewModel

    var body: some View {
        ZStack {
            if viewModel.cameraAuthorizationStatus == .authorized {
                CameraPreviewView(session: viewModel.cameraSession)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.7),
                        Color.clear,
                        Color.black.opacity(0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        RoundIconButton(systemName: "chevron.left") {
                            viewModel.returnHome()
                        }

                        Spacer()

                        VStack(spacing: 2) {
                            Text("Camera")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(OneScenePalette.secondaryText)

                            Text(viewModel.cameraLens.label)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(OneScenePalette.primaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    VStack(spacing: 16) {
                        Text("今日の1枚を撮影")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("ここで撮った写真だけが、今日の映画になります。")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(OneScenePalette.secondaryText)

                        HStack(spacing: 32) {
                            RoundIconButton(systemName: "arrow.triangle.2.circlepath.camera.fill") {
                                viewModel.switchCamera()
                            }

                            Button {
                                viewModel.capturePhoto()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 92, height: 92)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 72, height: 72)
                                }
                            }

                            RoundIconButton(systemName: "sparkles.rectangle.stack.fill") { }
                                .opacity(0)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                }
            } else {
                permissionCard
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            viewModel.prepareCamera()
        }
        .onDisappear {
            if viewModel.screen != .review {
                viewModel.stopCamera()
            }
        }
    }

    private var permissionCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(OneScenePalette.accent)

            Text("カメラの許可が必要です")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(OneScenePalette.primaryText)

            Text("OneScene はアプリ内で撮影した写真だけを使います。設定からカメラの使用を許可してください。")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(OneScenePalette.secondaryText)
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                viewModel.openAppSettings()
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button("ホームへ戻る") {
                viewModel.returnHome()
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(24)
        .background(OneScenePalette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(24)
    }
}

private struct CaptureReviewScreen: View {
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
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
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

private struct GeneratingScreen: View {
    let message: String
    @State private var pulse = false

    var body: some View {
        ZStack {
            OneScenePalette.backgroundGradient
                .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(OneScenePalette.accent.opacity(0.22))
                    .frame(width: pulse ? 280 : 220, height: pulse ? 280 : 220)
                    .blur(radius: 18)

                Circle()
                    .fill(OneScenePalette.secondaryAccent.opacity(0.18))
                    .frame(width: pulse ? 180 : 240, height: pulse ? 180 : 240)
                    .blur(radius: 24)
                    .offset(x: 36, y: 24)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.8)
            }

            VStack(spacing: 14) {
                Spacer()

                Text("Generating")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(OneScenePalette.secondaryText)
                    .textCase(.uppercase)

                Text(message)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(OneScenePalette.primaryText)
                    .multilineTextAlignment(.center)

                Text("撮影した1枚を OpenAI に送り、タイトル・コピー・ジャンルを組み立てています。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(OneScenePalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Spacer()
            }
            .padding(.bottom, 80)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

private struct ResultScreen: View {
    @ObservedObject var viewModel: OneSceneViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button {
                        viewModel.returnHome()
                    } label: {
                        Label("ホーム", systemImage: "house.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Spacer()

                    if let record = viewModel.latestRecord {
                        GenreBadge(genre: record.story.genre)
                    }
                }

                if let latestPoster = viewModel.latestPoster {
                    Image(uiImage: latestPoster)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.34), radius: 30, y: 18)
                }

                if let record = viewModel.latestRecord {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(record.story.title)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(OneScenePalette.primaryText)

                        Text(record.story.tagline)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(OneScenePalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Label(record.formattedCreatedAt, systemImage: "calendar")
                            Spacer()
                            Label(record.lens.label, systemImage: "camera.rotate")
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(OneScenePalette.secondaryText)
                    }
                    .padding(20)
                    .background(OneScenePalette.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

                VStack(spacing: 12) {
                    Button {
                        viewModel.saveLatestPosterToLibrary()
                    } label: {
                        Label("保存する", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.latestPoster == nil)

                    if let shareURL = viewModel.shareURL,
                       let latestPoster = viewModel.latestPoster,
                       let record = viewModel.latestRecord {
                        ShareLink(
                            item: shareURL,
                            preview: SharePreview(record.story.title, image: Image(uiImage: latestPoster))
                        ) {
                            Label("シェアする", systemImage: "square.and.arrow.up.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                Text("アプリ内カメラで撮った1枚だけを、その日の作品として残せます。保存やシェアは何度でも可能です。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(OneScenePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
    }
}

struct InfoChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(OneScenePalette.secondaryText)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(OneScenePalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OneScenePalette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct GenreBadge: View {
    let genre: MovieGenre

    var body: some View {
        Text(genre.rawValue)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(genre.badgeGradient)
            )
    }
}

private struct ToastPill: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(OneScenePalette.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OneScenePalette.primaryText)
                .frame(width: 54, height: 54)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        OneScenePalette.accent,
                        OneScenePalette.secondaryAccent
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(OneScenePalette.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(OneScenePalette.cardFill.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

enum OneScenePalette {
    static let background = Color(hex: "0F1117")
    static let cardBase = Color(hex: "171A22")
    static let primaryText = Color(hex: "F5F7FB")
    static let secondaryText = Color(hex: "A8B0C0")
    static let accent = Color(hex: "7C5CFF")
    static let secondaryAccent = Color(hex: "4FD1C5")
    static let warning = Color(hex: "FF6B6B")
    static let cardFill = cardBase.opacity(0.92)

    static let backgroundGradient = LinearGradient(
        colors: [
            background,
            Color(hex: "131824"),
            background
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

#Preview {
    ContentView()
}
