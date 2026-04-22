import AVFoundation
import SwiftUI

struct CameraScreen: View {
    @ObservedObject var viewModel: OneSceneViewModel
    @State private var isZoomGestureActive = false

    var body: some View {
        ZStack {
            if viewModel.cameraAuthorizationStatus == .authorized {
                authorizedContent
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                if !isZoomGestureActive {
                                    isZoomGestureActive = true
                                    viewModel.beginZoomGesture()
                                }

                                viewModel.updateZoomGesture(scale: scale)
                            }
                            .onEnded { scale in
                                if !isZoomGestureActive {
                                    viewModel.beginZoomGesture()
                                }

                                viewModel.updateZoomGesture(scale: scale)
                                viewModel.endZoomGesture()
                                isZoomGestureActive = false
                            }
                    )
            } else {
                permissionCard
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            viewModel.prepareCamera()
        }
        .onDisappear {
            if isZoomGestureActive {
                viewModel.endZoomGesture()
                isZoomGestureActive = false
            }

            if viewModel.screen != .review {
                viewModel.stopCamera()
            }
        }
    }

    private var authorizedContent: some View {
        ZStack {
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
            .allowsHitTesting(false)

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

                    Text("ここで撮った写真だけが、今日のポスターになります。")
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
