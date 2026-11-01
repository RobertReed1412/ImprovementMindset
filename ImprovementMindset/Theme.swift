import SwiftUI

enum Theme {

    static let displayFontName: String? = "DragonKnight"

    // MARK: Colors

    enum Palette {
        static let nightDeep   = Color(hex: 0x070A17)
        static let night       = Color(hex: 0x0A0E1F)
        static let nightRaised = Color(hex: 0x141A33)
        static let nightGlow   = Color(hex: 0x1B2540)

        static let gold        = Color(hex: 0xC9A24B)
        static let goldBright  = Color(hex: 0xE3C56B)
        static let goldDim     = Color(hex: 0x8A6E32)

        static let malachite     = Color(hex: 0x1E6B52)
        static let malachiteLite = Color(hex: 0x2E9B73)

        static let parchment     = Color(hex: 0xE8DCC0)
        static let parchmentWorn = Color(hex: 0xD8C8A4)
        static let parchmentInk  = Color(hex: 0x2A2418)

        static let oxblood       = Color(hex: 0x7B1418)
        static let oxbloodBright = Color(hex: 0x9E2024)

        static let bone      = Color(hex: 0xE8DCC0)
        static let boneDim   = Color(hex: 0xB5A982)
    }

    // MARK: Fonts

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = displayFontName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    // MARK: Gradients

    static var nightBackground: LinearGradient {
        LinearGradient(
            colors: [Palette.nightDeep, Palette.night, Palette.nightRaised],
            startPoint: .top, endPoint: .bottom)
    }

    static var malachiteGold: LinearGradient {
        LinearGradient(
            colors: [Palette.malachite, Palette.malachiteLite, Palette.gold],
            startPoint: .leading, endPoint: .trailing)
    }

    static var goldStroke: LinearGradient {
        LinearGradient(
            colors: [Palette.goldDim, Palette.goldBright, Palette.goldDim],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}

// MARK: - Reusable view modifiers

struct NightBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Theme.nightBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Palette.malachite.opacity(0.10), .clear],
                center: .center, startRadius: 5, endRadius: 420)
                .ignoresSafeArea()
            NebulaOverlay()
                .blendMode(.screen)
                .ignoresSafeArea()
            GrainOverlay(intensity: 0.30, density: 5000, particleSize: 3.5)
                .ignoresSafeArea()
            content
        }
    }
}

struct GoldFrame: ViewModifier {
    var cornerRadius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.Palette.nightRaised.opacity(0.6)))
            .overlay(ConstellationBorder())
    }
}

struct ParchmentSurface: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient(
                        colors: [Theme.Palette.parchment, Theme.Palette.parchmentWorn],
                        startPoint: .top, endPoint: .bottom)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.Palette.goldDim.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
    }
}

extension View {
    func nightBackground() -> some View { modifier(NightBackground()) }
    func goldFrame(cornerRadius: CGFloat = 14) -> some View {
        modifier(GoldFrame(cornerRadius: cornerRadius))
    }
    func parchmentSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(ParchmentSurface(cornerRadius: cornerRadius))
    }
}

struct CornerAccents: Shape {
    var inset: CGFloat = 4
    var length: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.insetBy(dx: inset, dy: inset)
        p.move(to: CGPoint(x: r.minX, y: r.minY + length))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + length, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - length, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + length))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - length))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - length, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + length, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - length))
        return p
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(16, weight: .semibold))
            .foregroundStyle(Theme.Palette.goldBright)
            .padding(.vertical, 10).padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Palette.night.opacity(configuration.isPressed ? 0.9 : 0.5)))
            .overlay(ConstellationBorder(inset: 2, nodeSize: 5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
