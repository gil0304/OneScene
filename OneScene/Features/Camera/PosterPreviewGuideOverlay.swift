import SwiftUI

struct PosterPreviewGuideOverlay: View {
    let imageAspectRatio: CGFloat

    private var layout: PosterPreviewGuideLayout {
        PosterPreviewGuideLayout(imageAspectRatio: imageAspectRatio)
    }

    var body: some View {
        GeometryReader { proxy in
            let titleZone = layout.titleZone(in: proxy.size)
            let cleanZone = layout.cleanImageZone(in: proxy.size)
            let taglineZone = layout.taglineZone(in: proxy.size)

            ZStack(alignment: .topLeading) {
                zoneHighlight(
                    title: "タイトル / 日付",
                    frame: titleZone,
                    tint: OneScenePalette.accent.opacity(0.22)
                )

                zoneHighlight(
                    title: "キャッチコピー",
                    frame: taglineZone,
                    tint: Color.black.opacity(0.30)
                )

                cleanImageHighlight(frame: cleanZone)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func zoneHighlight(title: String, frame: CGRect, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(tint)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .overlay(alignment: .topLeading) {
                guideLabel(title)
                    .offset(x: 14, y: 14)
            }
    }

    @ViewBuilder
    private func cleanImageHighlight(frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                OneScenePalette.secondaryAccent.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    private func guideLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(OneScenePalette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct PosterPreviewGuideLayout {
    let imageAspectRatio: CGFloat

    private var isLandscape: Bool {
        imageAspectRatio > 1.02
    }

    func titleZone(in size: CGSize) -> CGRect {
        let width = size.width * 0.78
        let height = size.height * (isLandscape ? 0.23 : 0.26)
        let originX = (size.width - width) / 2
        let originY = size.height * 0.08
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    func cleanImageZone(in size: CGSize) -> CGRect {
        let width = size.width * (isLandscape ? 0.60 : 0.66)
        let height = size.height * (isLandscape ? 0.33 : 0.35)
        let originX = (size.width - width) / 2
        let originY = size.height * (isLandscape ? 0.38 : 0.36)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    func taglineZone(in size: CGSize) -> CGRect {
        let width = size.width * 0.82
        let height = size.height * (isLandscape ? 0.16 : 0.18)
        let originX = (size.width - width) / 2
        let originY = size.height * (isLandscape ? 0.77 : 0.75)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
