import SwiftUI

// StyleKit — Animations.swift
// The app's motion vocabulary + a stylized animated emblem (circle-themed, to
// match the Circles feature). Reference patterns for the agent: reuse these
// timings and techniques instead of inventing new ones per view.

// MARK: - Standard motion tokens
// Keep animations consistent across the app by pulling from these.
enum Motion {
    static let tap = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let select = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let appear = Animation.easeOut(duration: 0.4)
    static let breathe = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
    static let slowSpin = Animation.linear(duration: 14).repeatForever(autoreverses: false)
}

// MARK: - Stylized animated circle emblem
// Concentric gold rings that slowly rotate, with a breathing glow. Good as a
// header flourish on the Circles screen or a loading/idle accent.
struct AnimatedCircleEmblem: View {
    var size: CGFloat = 120
    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            // outer breathing glow
            SwiftUI.Circle()
                .fill(RadialGradient(
                    colors: [Theme.Palette.malachite.opacity(breathe ? 0.35 : 0.15), .clear],
                    center: .center, startRadius: 2, endRadius: size * 0.6))
                .scaleEffect(breathe ? 1.05 : 0.9)

            // slowly rotating dashed gold ring
            SwiftUI.Circle()
                .strokeBorder(Theme.Palette.gold, style: StrokeStyle(lineWidth: 2, dash: [6, 10]))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(spin ? 360 : 0))

            // counter-rotating inner ring
            SwiftUI.Circle()
                .strokeBorder(Theme.Palette.goldDim, lineWidth: 1)
                .frame(width: size * 0.72, height: size * 0.72)
                .rotationEffect(.degrees(spin ? -360 : 0))

            // dots orbiting on the ring
            ForEach(0..<6, id: \.self) { i in
                SwiftUI.Circle()
                    .fill(Theme.Palette.goldBright)
                    .frame(width: 6, height: 6)
                    .offset(y: -size * 0.5)
                    .rotationEffect(.degrees(Double(i) / 6 * 360))
            }
            .rotationEffect(.degrees(spin ? 360 : 0))

            Image(systemName: "circle.circle")
                .font(.system(size: size * 0.28))
                .foregroundStyle(Theme.Palette.goldBright)
                .opacity(breathe ? 1 : 0.7)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(Motion.slowSpin) { spin = true }
            withAnimation(Motion.breathe) { breathe = true }
        }
    }
}

// MARK: - Press-scale helper
// Standard "tactile" button feedback: press to shrink slightly with a spring.
struct PressScale: ViewModifier {
    @State private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(Motion.tap, value: pressed)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

extension View {
    func pressScale() -> some View { modifier(PressScale()) }
}

#Preview("Animated Circle Emblem") {
    ZStack {
        Theme.nightBackground.ignoresSafeArea()
        AnimatedCircleEmblem(size: 160)
    }
}
