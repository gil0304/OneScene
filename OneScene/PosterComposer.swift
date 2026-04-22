//
//  PosterComposer.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import SwiftUI
import UIKit

@MainActor
struct PosterComposer {
    func renderPoster(from image: UIImage, story: GeneratedStory, createdAt: Date) -> UIImage {
        let posterView = PosterArtworkView(
            sourceImage: image,
            story: story,
            createdAt: createdAt,
            aspectRatio: image.aspectRatio
        )
        .frame(width: 1080, height: 1600)

        let renderer = ImageRenderer(content: posterView)
        renderer.scale = 1
        renderer.isOpaque = true

        return renderer.uiImage ?? image
    }
}

private struct PosterArtworkView: View {
    let sourceImage: UIImage
    let story: GeneratedStory
    let createdAt: Date
    let aspectRatio: CGFloat

    private var isLandscape: Bool {
        aspectRatio > 1.02
    }

    var body: some View {
        ZStack {
            posterBackground

            VStack(alignment: .leading, spacing: isLandscape ? 56 : 40) {
                header
                artworkFrame
                footer
            }
            .padding(.horizontal, 82)
            .padding(.top, 96)
            .padding(.bottom, 84)
        }
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(width: 180, height: 1)
                .padding(.top, 44)
                .padding(.leading, 46)
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(width: 220, height: 1)
                .padding(.bottom, 44)
                .padding(.trailing, 46)
        }
    }

    private var posterBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "06070C"),
                    story.genre.baseBackgroundStart,
                    story.genre.baseBackgroundEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    story.genre.highlight.opacity(0.45),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 560
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            GrainOverlay()
                .blendMode(.screen)
                .opacity(0.08)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Text("ONE SCENE")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.82))

                Text(story.genre.rawValue.uppercased())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(story.genre.badgeGradient)
                    )
            }

            Text(story.title)
                .font(.system(size: isLandscape ? 98 : 108, weight: .black, design: .serif))
                .tracking(-2.6)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.58)

            Text(dateText)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var artworkFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(.white.opacity(0.04))

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1.5)

            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: isLandscape ? 660 : 900)
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .fill(story.genre.imageTintGradient)
                        .opacity(0.25)
                        .blendMode(.screen)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.24), radius: 30, y: 18)
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: isLandscape ? 760 : 980)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(story.tagline)
                .font(.system(size: 42, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.72)

            HStack {
                Text("SHOT TODAY • MADE WITH ONE SCENE")
                Spacer()
                Text(isLandscape ? "LANDSCAPE FRAME" : "PORTRAIT FRAME")
            }
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.54))
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: createdAt).uppercased()
    }
}

private struct GrainOverlay: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let timestamp = timeline.date.timeIntervalSinceReferenceDate
                let cell: CGFloat = 14
                let columns = Int(size.width / cell) + 1
                let rows = Int(size.height / cell) + 1

                for row in 0..<rows {
                    for column in 0..<columns {
                        let x = CGFloat(column) * cell
                        let y = CGFloat(row) * cell
                        let raw = sin(Double(column * 19 + row * 7) + timestamp * 5.6)
                        let opacity = max(0, raw) * 0.12
                        let rect = CGRect(x: x, y: y, width: cell * 0.55, height: cell * 0.55)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                    }
                }
            }
        }
    }
}

private extension MovieGenre {
    var baseBackgroundStart: Color {
        switch self {
        case .youth:
            return Color(hex: "142236")
        case .romance:
            return Color(hex: "311722")
        case .suspense:
            return Color(hex: "111318")
        case .scienceFiction:
            return Color(hex: "071C23")
        case .horror:
            return Color(hex: "150E12")
        case .humanDrama:
            return Color(hex: "1C1714")
        case .roadMovie:
            return Color(hex: "22160F")
        case .fantasy:
            return Color(hex: "171429")
        }
    }

    var baseBackgroundEnd: Color {
        switch self {
        case .youth:
            return Color(hex: "0B111D")
        case .romance:
            return Color(hex: "1D1116")
        case .suspense:
            return Color(hex: "090B10")
        case .scienceFiction:
            return Color(hex: "07131D")
        case .horror:
            return Color(hex: "0A0C0A")
        case .humanDrama:
            return Color(hex: "0E1014")
        case .roadMovie:
            return Color(hex: "0E0C12")
        case .fantasy:
            return Color(hex: "0A0E18")
        }
    }

    var highlight: Color {
        switch self {
        case .youth:
            return Color(hex: "7FB9FF")
        case .romance:
            return Color(hex: "FF93A5")
        case .suspense:
            return Color(hex: "798194")
        case .scienceFiction:
            return Color(hex: "3BD6D9")
        case .horror:
            return Color(hex: "C43636")
        case .humanDrama:
            return Color(hex: "C59A72")
        case .roadMovie:
            return Color(hex: "F5A64D")
        case .fantasy:
            return Color(hex: "8780FF")
        }
    }

    var imageTintGradient: LinearGradient {
        switch self {
        case .youth:
            return LinearGradient(colors: [Color(hex: "A9D2FF"), Color(hex: "FFFFFF")], startPoint: .top, endPoint: .bottom)
        case .romance:
            return LinearGradient(colors: [Color(hex: "FFC0B3"), Color(hex: "FFB0D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .suspense:
            return LinearGradient(colors: [Color(hex: "28313E"), Color(hex: "111318")], startPoint: .top, endPoint: .bottom)
        case .scienceFiction:
            return LinearGradient(colors: [Color(hex: "29F0FF"), Color(hex: "2A8CFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .horror:
            return LinearGradient(colors: [Color(hex: "2D7A54"), Color(hex: "851C2A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .humanDrama:
            return LinearGradient(colors: [Color(hex: "F1C08A"), Color(hex: "B1855B")], startPoint: .top, endPoint: .bottom)
        case .roadMovie:
            return LinearGradient(colors: [Color(hex: "FFD88B"), Color(hex: "D97145")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fantasy:
            return LinearGradient(colors: [Color(hex: "B0A8FF"), Color(hex: "71CCFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
