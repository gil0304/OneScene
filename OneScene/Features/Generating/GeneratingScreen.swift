import SwiftUI

struct GeneratingScreen: View {
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
