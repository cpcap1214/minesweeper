import SwiftUI

extension Color {
    static let winGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let winDark = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let ledOn = Color(red: 1, green: 0, blue: 0)
    static let ledOff = Color(red: 0.32, green: 0, blue: 0)
}

// MARK: - 立體斜邊（凸起 / 凹陷）

struct Bevel: View {
    var raised: Bool
    var width: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let w = width, W = size.width, H = size.height
            var topLeft = Path()
            topLeft.addLines([
                .init(x: 0, y: 0), .init(x: W, y: 0), .init(x: W - w, y: w),
                .init(x: w, y: w), .init(x: w, y: H - w), .init(x: 0, y: H),
            ])
            var bottomRight = Path()
            bottomRight.addLines([
                .init(x: W, y: 0), .init(x: W, y: H), .init(x: 0, y: H),
                .init(x: w, y: H - w), .init(x: W - w, y: H - w), .init(x: W - w, y: w),
            ])
            ctx.fill(topLeft, with: .color(raised ? .white : .winDark))
            ctx.fill(bottomRight, with: .color(raised ? .winDark : .white))
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func bevel(raised: Bool, width: CGFloat) -> some View {
        overlay(Bevel(raised: raised, width: width))
    }
}

// MARK: - 七段顯示器

struct SevenSegmentDigit: View {
    let char: Character

    private static let map: [Character: Set<Character>] = [
        "0": ["a", "b", "c", "d", "e", "f"],
        "1": ["b", "c"],
        "2": ["a", "b", "g", "e", "d"],
        "3": ["a", "b", "g", "c", "d"],
        "4": ["f", "g", "b", "c"],
        "5": ["a", "f", "g", "c", "d"],
        "6": ["a", "f", "g", "e", "d", "c"],
        "7": ["a", "b", "c"],
        "8": ["a", "b", "c", "d", "e", "f", "g"],
        "9": ["a", "b", "c", "d", "f", "g"],
        "-": ["g"],
    ]

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let t = w * 0.2, g = t * 0.25
            let on = Self.map[char] ?? []

            func horizontal(_ y: CGFloat) -> Path {
                let x0 = t / 2 + g, x1 = w - t / 2 - g
                var p = Path()
                p.addLines([
                    .init(x: x0, y: y), .init(x: x0 + t / 2, y: y - t / 2),
                    .init(x: x1 - t / 2, y: y - t / 2), .init(x: x1, y: y),
                    .init(x: x1 - t / 2, y: y + t / 2), .init(x: x0 + t / 2, y: y + t / 2),
                ])
                p.closeSubpath()
                return p
            }
            func vertical(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
                var p = Path()
                p.addLines([
                    .init(x: x, y: y0), .init(x: x + t / 2, y: y0 + t / 2),
                    .init(x: x + t / 2, y: y1 - t / 2), .init(x: x, y: y1),
                    .init(x: x - t / 2, y: y1 - t / 2), .init(x: x - t / 2, y: y0 + t / 2),
                ])
                p.closeSubpath()
                return p
            }

            let segments: [(Character, Path)] = [
                ("a", horizontal(t / 2)),
                ("g", horizontal(h / 2)),
                ("d", horizontal(h - t / 2)),
                ("f", vertical(t / 2, t / 2 + g, h / 2 - g)),
                ("b", vertical(w - t / 2, t / 2 + g, h / 2 - g)),
                ("e", vertical(t / 2, h / 2 + g, h - t / 2 - g)),
                ("c", vertical(w - t / 2, h / 2 + g, h - t / 2 - g)),
            ]
            for (name, path) in segments {
                ctx.fill(path, with: .color(on.contains(name) ? .ledOn : .ledOff))
            }
        }
    }
}

struct LEDCounter: View {
    let value: Int
    var digitHeight: CGFloat = 30

    private var text: String {
        let v = min(max(value, -99), 999)
        return v < 0 ? "-" + String(format: "%02d", -v) : String(format: "%03d", v)
    }

    var body: some View {
        HStack(spacing: digitHeight * 0.08) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                SevenSegmentDigit(char: ch)
                    .frame(width: digitHeight * 0.55, height: digitHeight)
            }
        }
        .padding(digitHeight * 0.1)
        .background(Color.black)
        .bevel(raised: false, width: 1)
    }
}

// MARK: - 圖示

struct MineIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = s * 0.28
            var spikes = Path()
            for k in 0..<4 {
                let a = Double(k) * .pi / 4
                let dx = cos(a) * s * (k % 2 == 0 ? 0.42 : 0.36)
                let dy = sin(a) * s * (k % 2 == 0 ? 0.42 : 0.36)
                spikes.move(to: .init(x: c.x - dx, y: c.y - dy))
                spikes.addLine(to: .init(x: c.x + dx, y: c.y + dy))
            }
            ctx.stroke(spikes, with: .color(.black), lineWidth: s * 0.08)
            ctx.fill(Path(ellipseIn: .init(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.black))
            let hr = r * 0.35
            ctx.fill(Path(ellipseIn: .init(x: c.x - r * 0.55, y: c.y - r * 0.55, width: hr, height: hr)), with: .color(.white))
        }
    }
}

struct FlagIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let ox = (size.width - s) / 2, oy = (size.height - s) / 2
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: ox + x * s, y: oy + y * s) }

            var base = Path()
            base.addRect(.init(origin: p(0.2, 0.74), size: .init(width: s * 0.6, height: s * 0.1)))
            base.addRect(.init(origin: p(0.32, 0.66), size: .init(width: s * 0.36, height: s * 0.08)))
            ctx.fill(base, with: .color(.black))

            var pole = Path()
            pole.addRect(.init(origin: p(0.5, 0.18), size: .init(width: s * 0.07, height: s * 0.5)))
            ctx.fill(pole, with: .color(.black))

            var flag = Path()
            flag.addLines([p(0.57, 0.14), p(0.57, 0.5), p(0.2, 0.32)])
            flag.closeSubpath()
            ctx.fill(flag, with: .color(.red))
        }
    }
}

struct CrossIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let i = min(size.width, size.height) * 0.12
            var p = Path()
            p.move(to: .init(x: i, y: i)); p.addLine(to: .init(x: size.width - i, y: size.height - i))
            p.move(to: .init(x: size.width - i, y: i)); p.addLine(to: .init(x: i, y: size.height - i))
            ctx.stroke(p, with: .color(.red), lineWidth: min(size.width, size.height) * 0.1)
        }
    }
}

// MARK: - 笑臉

struct SmileyFace: View {
    enum Mood { case happy, worried, dead, cool }
    let mood: Mood

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let ox = (size.width - s) / 2, oy = (size.height - s) / 2
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: ox + x * s, y: oy + y * s) }
            let lw = s * 0.06

            let face = Path(ellipseIn: .init(origin: p(0.04, 0.04), size: .init(width: s * 0.92, height: s * 0.92)))
            ctx.fill(face, with: .color(.yellow))
            ctx.stroke(face, with: .color(.black), lineWidth: lw)

            func eye(_ x: CGFloat) {
                let r = s * 0.065
                ctx.fill(Path(ellipseIn: .init(x: ox + x * s - r, y: oy + 0.38 * s - r, width: r * 2, height: r * 2)), with: .color(.black))
            }
            func xEye(_ x: CGFloat) {
                var e = Path()
                let d = s * 0.07, cx = ox + x * s, cy = oy + 0.38 * s
                e.move(to: .init(x: cx - d, y: cy - d)); e.addLine(to: .init(x: cx + d, y: cy + d))
                e.move(to: .init(x: cx + d, y: cy - d)); e.addLine(to: .init(x: cx - d, y: cy + d))
                ctx.stroke(e, with: .color(.black), lineWidth: lw * 0.8)
            }

            switch mood {
            case .happy, .worried:
                eye(0.36); eye(0.64)
            case .dead:
                xEye(0.36); xEye(0.64)
            case .cool:
                var glasses = Path()
                glasses.addRoundedRect(in: .init(origin: p(0.2, 0.3), size: .init(width: s * 0.26, height: s * 0.16)), cornerSize: .init(width: s * 0.05, height: s * 0.05))
                glasses.addRoundedRect(in: .init(origin: p(0.54, 0.3), size: .init(width: s * 0.26, height: s * 0.16)), cornerSize: .init(width: s * 0.05, height: s * 0.05))
                ctx.fill(glasses, with: .color(.black))
                var bridge = Path()
                bridge.move(to: p(0.08, 0.34)); bridge.addLine(to: p(0.92, 0.34))
                ctx.stroke(bridge, with: .color(.black), lineWidth: lw * 0.8)
            }

            var mouth = Path()
            switch mood {
            case .happy, .cool:
                mouth.addArc(center: p(0.5, 0.52), radius: s * 0.22, startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
                ctx.stroke(mouth, with: .color(.black), lineWidth: lw)
            case .dead:
                mouth.addArc(center: p(0.5, 0.86), radius: s * 0.2, startAngle: .degrees(-150), endAngle: .degrees(-30), clockwise: false)
                ctx.stroke(mouth, with: .color(.black), lineWidth: lw)
            case .worried:
                let r = s * 0.09
                mouth.addEllipse(in: .init(x: ox + 0.5 * s - r, y: oy + 0.68 * s - r, width: r * 2, height: r * 2))
                ctx.stroke(mouth, with: .color(.black), lineWidth: lw)
            }
        }
    }
}
