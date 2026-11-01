import SwiftUI

struct WaxSeal: View {
    enum Tone { case red, black, white, gold }
    let tone: Tone
    var size: CGFloat = 44
    var symbol: String = "crown.fill"

    private var base: Color {
        switch tone {
        case .red:   return Color(hex: 0x7B1418)
        case .black: return Color(hex: 0x1A1A1C)
        case .white: return Color(hex: 0xE8DCC0)
        case .gold:  return Color(hex: 0xB8902C)
        }
    }
    private var rim: Color {
        switch tone {
        case .red:   return Color(hex: 0x4E0C0F)
        case .black: return Color(hex: 0x000000)
        case .white: return Color(hex: 0xBFB48C)
        case .gold:  return Color(hex: 0x7A5E18)
        }
    }
    private var sheen: Color {
        switch tone {
        case .red:   return Color(hex: 0xC23A3E)
        case .black: return Color(hex: 0x3A3A40)
        case .white: return .white
        case .gold:  return Color(hex: 0xF0D26A)
        }
    }
    private var crest: Color {
        tone == .white ? Color(hex: 0x9A8A5C) : .black.opacity(0.35)
    }

    var body: some View {
        ZStack {
            WaxBlob()
                .fill(rim)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.45), radius: size * 0.06,
                        x: size * 0.02, y: size * 0.05)

            SwiftUI.Circle()
                .fill(RadialGradient(
                    colors: [sheen, base, rim],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: size * 0.02, endRadius: size * 0.55))
                .frame(width: size * 0.82, height: size * 0.82)

            SwiftUI.Circle()
                .stroke(crest, lineWidth: max(1, size * 0.025))
                .frame(width: size * 0.6, height: size * 0.6)

            ZStack {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.3, weight: .black))
                    .foregroundStyle(crest)
                    .offset(y: size * 0.012)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.3, weight: .black))
                    .foregroundStyle(sheen.opacity(0.5))
                    .offset(y: -size * 0.012)
                    .blendMode(.softLight)
            }

            Ellipse()
                .fill(LinearGradient(
                    colors: [.white.opacity(tone == .white ? 0.5 : 0.35), .clear],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.5, height: size * 0.28)
                .offset(y: -size * 0.22)
                .blur(radius: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

struct WaxBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let bumps = 11
        var p = Path()
        for i in 0...bumps * 2 {
            let frac = Double(i) / Double(bumps * 2)
            let angle = frac * 2 * .pi
            let wobble = (i % 2 == 0) ? 1.0 : 0.93
            let rr = r * wobble
            let pt = CGPoint(x: c.x + cos(angle) * rr, y: c.y + sin(angle) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

extension WaxSeal.Tone {
    init?(seal: SealKind) {
        switch seal {
        case .red: self = .red
        case .black: self = .black
        case .white: self = .white
        case .none: return nil
        }
    }
}
