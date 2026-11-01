import SwiftUI

struct LaunchView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            Theme.nightBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Palette.malachite.opacity(glow ? 0.18 : 0.08), .clear],
                center: .center, startRadius: 5, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image("SealCrest")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                    .scaleEffect(glow ? 1.0 : 0.94)

                VStack(spacing: 6) {
                    Text("The Improvement")
                    Text("Mindset")
                }
                .font(Theme.display(34, weight: .bold))
                .foregroundStyle(Theme.Palette.goldBright)
                .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Rectangle().fill(Theme.Palette.goldDim).frame(width: 50, height: 1)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8)).foregroundStyle(Theme.Palette.gold)
                    Rectangle().fill(Theme.Palette.goldDim).frame(width: 50, height: 1)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
