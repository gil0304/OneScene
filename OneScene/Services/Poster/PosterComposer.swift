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
        GeometryReader { proxy in
            ZStack {
                Color.black

                posterImage(size: proxy.size)
                cinematicOverlays
                neonFrame
                posterContent
            }
        }
    }

    private func posterImage(size: CGSize) -> some View {
        ZStack {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .blur(radius: isLandscape ? 24 : 0)
                .clipped()

            Color.black.opacity(isLandscape ? 0.28 : 0)

            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFit()
                .frame(
                    width: size.width * (isLandscape ? 0.96 : 1.05),
                    height: size.height * (isLandscape ? 0.82 : 1.02)
                )
                .clipped()
        }
        .overlay {
            LinearGradient(
                colors: [
                    story.genre.posterTintTop.opacity(0.30),
                    Color.clear,
                    story.genre.posterTintBottom.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)
        }
        .overlay {
            Rectangle()
                .fill(Color.black.opacity(isLandscape ? 0.16 : 0.06))
        }
    }

    private var cinematicOverlays: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.84),
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    story.genre.posterGlow.opacity(0.42),
                    Color.clear
                ],
                center: .top,
                startRadius: 60,
                endRadius: 620
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GrainOverlay()
                .blendMode(.screen)
                .opacity(0.09)
        }
    }

    private var neonFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(story.genre.posterGlow.opacity(0.72), lineWidth: 5)
                .blur(radius: 16)
                .padding(24)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 2.5)
                .padding(24)
                .shadow(color: story.genre.posterGlow.opacity(0.72), radius: 18)
        }
    }

    private var posterContent: some View {
        VStack(spacing: 0) {
            Text(dateText)
                .font(.system(size: 28, weight: .medium, design: .serif))
                .tracking(10)
                .foregroundStyle(Color.white.opacity(0.9))
                .shadow(color: story.genre.posterGlow.opacity(0.75), radius: 12)
                .padding(.top, 104)

            Spacer()
                .frame(height: isLandscape ? 86 : 104)

            VStack(spacing: 22) {
                Text(story.title)
                    .font(.system(size: isLandscape ? 116 : 140, weight: .heavy, design: .serif))
                    .lineSpacing(isLandscape ? 18 : 20)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.97))
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                    .shadow(color: story.genre.posterGlow.opacity(0.82), radius: 22)
                    .shadow(color: Color.white.opacity(0.25), radius: 6)

                Text(story.genre.rawValue)
                    .font(.system(size: 32, weight: .medium, design: .serif))
                    .tracking(12)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .shadow(color: story.genre.posterGlow.opacity(0.64), radius: 14)
            }
            .frame(maxWidth: isLandscape ? 820 : 860)

            Spacer()

            VStack(spacing: 28) {
                Text(story.tagline)
                    .font(.system(size: isLandscape ? 34 : 38, weight: .medium, design: .serif))
                    .lineSpacing(12)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(maxWidth: 860)
                    .minimumScaleFactor(0.62)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.35), radius: 8)

                (
                    Text("Generated by ")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                    +
                    Text("OneScene")
                        .font(.oneSceneBrand(size: 24))
                )
                .tracking(3)
                .foregroundStyle(Color.white.opacity(0.86))
                .shadow(color: story.genre.posterGlow.opacity(0.55), radius: 12)
            }
            .padding(.bottom, 76)
        }
        .padding(.horizontal, 72)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: createdAt)
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
    var posterTintTop: Color {
        switch self {
        case .youth:
            return Color(hex: "8D6BFF")
        case .romance:
            return Color(hex: "FF6EA8")
        case .suspense:
            return Color(hex: "384250")
        case .scienceFiction:
            return Color(hex: "13B8E6")
        case .horror:
            return Color(hex: "8B1E3F")
        case .humanDrama:
            return Color(hex: "B57A4C")
        case .roadMovie:
            return Color(hex: "FF914D")
        case .fantasy:
            return Color(hex: "7C5CFF")
        }
    }

    var posterTintBottom: Color {
        switch self {
        case .youth:
            return Color(hex: "FF7AC7")
        case .romance:
            return Color(hex: "FF9B85")
        case .suspense:
            return Color(hex: "1E293B")
        case .scienceFiction:
            return Color(hex: "2DE2C4")
        case .horror:
            return Color(hex: "0F5B3A")
        case .humanDrama:
            return Color(hex: "8E6A52")
        case .roadMovie:
            return Color(hex: "FFB547")
        case .fantasy:
            return Color(hex: "54B8FF")
        }
    }

    var posterGlow: Color {
        switch self {
        case .youth:
            return Color(hex: "D98DFF")
        case .romance:
            return Color(hex: "FF82C6")
        case .suspense:
            return Color(hex: "94A3B8")
        case .scienceFiction:
            return Color(hex: "42E8E0")
        case .horror:
            return Color(hex: "71D68A")
        case .humanDrama:
            return Color(hex: "E4B26E")
        case .roadMovie:
            return Color(hex: "FFB067")
        case .fantasy:
            return Color(hex: "AA8BFF")
        }
    }
}
