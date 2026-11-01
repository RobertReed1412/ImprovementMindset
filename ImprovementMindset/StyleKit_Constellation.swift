import SwiftUI

// StyleKit — Constellation.swift
// Procedural constellation border: thin gold lines connecting 8 nodes (4 corners
// + 4 edge midpoints), each node is a 4-pointed sparkle star with a radial glow.
// Replaces the plain gold stroke + CornerAccents on GoldFrame cards.

// MARK: - Constellation border

struct ConstellationBorder: View {
    var inset: CGFloat = 4
    var nodeSize: CGFloat = 7      // vertical arm radius of each sparkle
    var lineOpacity: Double = 0.80

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: inset, y: inset,
                           width: size.width - inset * 2,
                           height: size.height - inset * 2)

            // 8 nodes: 4 corners then 4 edge midpoints, in perimeter order
            let nodes: [CGPoint] = [
                CGPoint(x: r.minX, y: r.minY),   // top-left
                CGPoint(x: r.midX, y: r.minY),   // top-mid
                CGPoint(x: r.maxX, y: r.minY),   // top-right
                CGPoint(x: r.maxX, y: r.midY),   // right-mid
                CGPoint(x: r.maxX, y: r.maxY),   // bottom-right
                CGPoint(x: r.midX, y: r.maxY),   // bottom-mid
                CGPoint(x: r.minX, y: r.maxY),   // bottom-left
                CGPoint(x: r.minX, y: r.midY),   // left-mid
            ]

            // — constellation lines between adjacent nodes —
            for i in 0..<nodes.count {
                let a = nodes[i], b = nodes[(i + 1) % nodes.count]
                var seg = Path()
                seg.move(to: a)
                seg.addLine(to: b)
                ctx.stroke(seg, with: .linearGradient(
                    Gradient(colors: [
                        Theme.Palette.goldDim.opacity(lineOpacity * 0.60),
                        Theme.Palette.goldBright.opacity(lineOpacity),
                        Theme.Palette.goldDim.opacity(lineOpacity * 0.60),
                    ]),
                    startPoint: a, endPoint: b
                ), lineWidth: 0.65)
            }

            // — sparkle nodes with radial glow —
            let horizR = nodeSize * 0.42     // shorter horizontal arm
            let glowR  = nodeSize * 1.25

            for pt in nodes {
                // soft radial colour burst behind the star
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pt.x - glowR, y: pt.y - glowR,
                                          width: glowR * 2, height: glowR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Theme.Palette.goldBright.opacity(0.45), .clear]),
                        center: pt, startRadius: 0, endRadius: glowR))

                // 4-pointed sparkle filled centre-to-tip gradient
                ctx.fill(
                    sparklePath(center: pt, vertR: nodeSize, horizR: horizR),
                    with: .radialGradient(
                        Gradient(colors: [Theme.Palette.goldBright,
                                          Theme.Palette.gold.opacity(0.50)]),
                        center: pt, startRadius: 0, endRadius: nodeSize * 0.80))
            }
        }
        .allowsHitTesting(false)
    }

    // 4-pointed sparkle: long vertical tips, short horizontal tips, concave
    // bezier waist between each pair. C1-smooth at every tip.
    private func sparklePath(center: CGPoint,
                              vertR: CGFloat,
                              horizR: CGFloat,
                              pull: CGFloat = 0.25) -> Path {
        let cx = center.x, cy = center.y
        let top    = CGPoint(x: cx,          y: cy - vertR)
        let right  = CGPoint(x: cx + horizR, y: cy)
        let bottom = CGPoint(x: cx,          y: cy + vertR)
        let left   = CGPoint(x: cx - horizR, y: cy)

        // Shared inner control points at pull% of arm length from centre.
        // Same point used as cp2 of one segment and cp1 of the next, giving
        // smooth C1 joins at each tip without separate tangent calculation.
        let ct = CGPoint(x: cx,              y: cy - vertR  * pull)
        let cr = CGPoint(x: cx + horizR * pull, y: cy)
        let cb = CGPoint(x: cx,              y: cy + vertR  * pull)
        let cl = CGPoint(x: cx - horizR * pull, y: cy)

        var p = Path()
        p.move(to: top)
        p.addCurve(to: right,  control1: ct, control2: cr)
        p.addCurve(to: bottom, control1: cr, control2: cb)
        p.addCurve(to: left,   control1: cb, control2: cl)
        p.addCurve(to: top,    control1: cl, control2: ct)
        p.closeSubpath()
        return p
    }
}

#Preview("Constellation Border") {
    VStack(spacing: 24) {
        Text("Hero Card — full width")
            .font(Theme.display(17))
            .foregroundStyle(Theme.Palette.bone)
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Theme.Palette.nightRaised.opacity(0.6))
            .overlay(ConstellationBorder())

        HStack(spacing: 16) {
            Text("Narrow")
                .font(Theme.display(14))
                .foregroundStyle(Theme.Palette.boneDim)
                .padding(14)
                .background(Theme.Palette.nightRaised.opacity(0.6))
                .overlay(ConstellationBorder(inset: 3, nodeSize: 5.5))

            Text("Narrow")
                .font(Theme.display(14))
                .foregroundStyle(Theme.Palette.boneDim)
                .padding(14)
                .background(Theme.Palette.nightRaised.opacity(0.6))
                .overlay(ConstellationBorder(inset: 3, nodeSize: 5.5))
        }

        Text("Wider card with larger nodes")
            .font(Theme.display(15))
            .foregroundStyle(Theme.Palette.bone)
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(Theme.Palette.nightRaised.opacity(0.6))
            .overlay(ConstellationBorder(nodeSize: 9))
    }
    .padding(28)
    .background(Theme.Palette.night)
}
