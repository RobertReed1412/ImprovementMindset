import SwiftUI

// StyleKit — Textures.swift
// Procedural texture overlays. No image files needed — these build texture from
// gradients, noise, and blend modes, all tinted from Theme tokens. Reference
// patterns for the agent: extend these rather than hardcoding effects in views.

// MARK: - Grain overlay
// A subtle film-grain / paper-tooth speckle. Layer OVER a surface to kill the
// "flat digital" look. Deterministic so it doesn't shimmer between redraws.
struct GrainOverlay: View {
    var intensity: Double = 0.05          // 0…0.15 is tasteful
    var density: Int = 700
    var seed: UInt64 = 42
    var particleSize: Double = 1.0        // multiplier on base grain radius

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: seed)
            for _ in 0..<density {
                let x = Double(rng.next()) / Double(UInt64.max) * size.width
                let y = Double(rng.next()) / Double(UInt64.max) * size.height
                let a = intensity * (Double(rng.next()) / Double(UInt64.max))
                let r = (0.5 + Double(rng.next()) / Double(UInt64.max)) * particleSize
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
            }
        }
        .allowsHitTesting(false)
        .blendMode(.overlay)
    }
}

// MARK: - Nebula overlay
// Organic cloudy light patches that break up flat dark gradients, giving the
// layered painted-canvas depth visible in the reference background texture.
// Layer UNDER grain and OVER the base gradient; blend mode stays normal so
// opacity alone controls how much colour adds — no text-contrast risk.
struct NebulaOverlay: View {
    var seed: UInt64 = 91

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: seed)

            // — large atmospheric blobs (broad colour lift) —
            for _ in 0..<10 {
                let x   = Double(rng.next()) / Double(UInt64.max) * size.width
                let y   = Double(rng.next()) / Double(UInt64.max) * size.height
                let r   = 160 + Double(rng.next()) / Double(UInt64.max) * 180   // 160…340pt
                let a   = 0.35 + Double(rng.next()) / Double(UInt64.max) * 0.30 // 0.35…0.65
                let alt = rng.next() % 2 == 0
                let col = alt ? Theme.Palette.nightGlow.opacity(a)
                              : Theme.Palette.nightRaised.opacity(a)
                let center = CGPoint(x: x, y: y)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(Gradient(colors: [col, .clear]),
                                          center: center, startRadius: 0, endRadius: r))
            }

            // — medium cloud patches (depth detail) —
            for _ in 0..<16 {
                let x   = Double(rng.next()) / Double(UInt64.max) * size.width
                let y   = Double(rng.next()) / Double(UInt64.max) * size.height
                let r   = 40 + Double(rng.next()) / Double(UInt64.max) * 100    // 40…140pt
                let a   = 0.20 + Double(rng.next()) / Double(UInt64.max) * 0.30 // 0.20…0.50
                let col = Theme.Palette.nightGlow.opacity(a)
                let center = CGPoint(x: x, y: y)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(Gradient(colors: [col, .clear]),
                                          center: center, startRadius: 0, endRadius: r))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Brushed gold fill
// A metallic gold with directional streaks + sheen. Use for hero accents,
// medallions, or as a stroke fill on frames.
struct BrushedGold: View {
    var angle: Angle = .degrees(20)
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.goldDim, Theme.Palette.gold,
                         Theme.Palette.goldBright, Theme.Palette.gold,
                         Theme.Palette.goldDim],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            // fine brushed streaks
            Canvas { ctx, size in
                var rng = SplitMix64(seed: 7)
                for _ in 0..<120 {
                    let y = Double(rng.next()) / Double(UInt64.max) * size.height
                    let a = 0.06 * (Double(rng.next()) / Double(UInt64.max))
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y + 6))
                    ctx.stroke(p, with: .color(.white.opacity(a)), lineWidth: 0.5)
                }
            }
            .blendMode(.overlay)
        }
        .rotationEffect(angle)
        .scaleEffect(1.4)   // hide rotation gaps
        .clipped()
    }
}

// MARK: - Wax gloss overlay
// The domed top-highlight used on wax seals, extracted so any element can get
// that "pressed glossy" read.
struct WaxGloss: View {
    var body: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.3)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.22)
                .blur(radius: geo.size.width * 0.02)
                .allowsHitTesting(false)
        }
    }
}

// Deterministic tiny RNG so grain is stable across redraws.
struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension View {
    /// Add procedural grain on top of this view.
    func grain(_ intensity: Double = 0.05) -> some View {
        overlay(GrainOverlay(intensity: intensity))
    }
    /// Add the wax-style domed gloss on top of this view.
    func waxGloss() -> some View { overlay(WaxGloss()) }
}

#Preview("Textures") {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 16)
            .fill(Theme.Palette.parchment)
            .frame(height: 90).grain(0.08)
            .overlay(Text("Parchment + grain").foregroundStyle(Theme.Palette.parchmentInk))
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.clear)
            .frame(height: 90)
            .background(BrushedGold().clipShape(RoundedRectangle(cornerRadius: 16)))
            .overlay(Text("Brushed gold").foregroundStyle(.black.opacity(0.6)))
        SwiftUI.Circle().fill(Theme.Palette.oxblood).frame(width: 90, height: 90).waxGloss()
    }
    .padding(30)
    .background(Theme.Palette.night)
}
