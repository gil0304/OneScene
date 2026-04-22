import SwiftUI

struct ResultScreen: View {
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
