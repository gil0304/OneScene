import SwiftUI

struct HomeScreen: View {
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
                            .font(.oneSceneBrand(size: 44))
                            .tracking(1.2)
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
                }

                statusCard

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
                    .disabled(viewModel.hasGeneratedToday || !viewModel.isOpenAIConfigured)
                    .opacity((viewModel.hasGeneratedToday || !viewModel.isOpenAIConfigured) ? 0.7 : 1)

                    Button {
                        viewModel.openLatestResult()
                    } label: {
                        Label("前回の作品を見る", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!viewModel.canViewLatestWork)
                    .opacity(viewModel.canViewLatestWork ? 1 : 0.55)
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
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(viewModel.todayStatusText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(OneScenePalette.primaryText)
            }

            Text(viewModel.statusDetailText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(OneScenePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            OneScenePalette.cardBase,
                            statusColor.opacity(0.22)
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

    private var statusColor: Color {
        if !viewModel.isOpenAIConfigured {
            return OneScenePalette.warning
        }

        return viewModel.hasGeneratedToday ? OneScenePalette.warning : OneScenePalette.accent
    }
}
