// 產生 App 圖示：經典灰色凸起方塊 + 中間一顆地雷
import AppKit

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// 讓座標原點在左上角
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, 1])! }
let gray = rgb(0.75, 0.75, 0.75), dark = rgb(0.5, 0.5, 0.5), white = rgb(1, 1, 1), black = rgb(0, 0, 0)

func bevel(_ r: CGRect, _ w: CGFloat, raised: Bool) {
    let (x0, y0, x1, y1) = (r.minX, r.minY, r.maxX, r.maxY)
    ctx.setFillColor(raised ? white : dark)
    ctx.addLines(between: [.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1 - w, y: y0 + w),
                           .init(x: x0 + w, y: y0 + w), .init(x: x0 + w, y: y1 - w), .init(x: x0, y: y1)])
    ctx.fillPath()
    ctx.setFillColor(raised ? dark : white)
    ctx.addLines(between: [.init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1),
                           .init(x: x0 + w, y: y1 - w), .init(x: x1 - w, y: y1 - w), .init(x: x1 - w, y: y0 + w)])
    ctx.fillPath()
}

// 背景
ctx.setFillColor(gray); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
// 凹陷的雷區框
let inner = CGRect(x: 120, y: 120, width: 784, height: 784)
bevel(inner, 24, raised: false)
// 3×3 小格：外圍凸起，中間翻開
let cell = (inner.width - 48) / 3
for r in 0..<3 {
    for c in 0..<3 {
        let rect = CGRect(x: inner.minX + 24 + CGFloat(c) * cell, y: inner.minY + 24 + CGFloat(r) * cell, width: cell, height: cell)
        if r == 1 && c == 1 {
            ctx.setFillColor(rgb(1, 0, 0)); ctx.fill(rect)
            ctx.setStrokeColor(dark); ctx.setLineWidth(4); ctx.stroke(rect)
        } else {
            ctx.setFillColor(gray); ctx.fill(rect)
            bevel(rect, 22, raised: true)
        }
    }
}

// 地雷（畫在中間那格，稍微超出一點）
let c = CGPoint(x: S / 2, y: S / 2)
ctx.setStrokeColor(black); ctx.setLineCap(.butt)
ctx.setLineWidth(26)
for k in 0..<4 {
    let a = CGFloat(k) * .pi / 4
    let len: CGFloat = k % 2 == 0 ? 150 : 128
    ctx.move(to: .init(x: c.x - cos(a) * len, y: c.y - sin(a) * len))
    ctx.addLine(to: .init(x: c.x + cos(a) * len, y: c.y + sin(a) * len))
}
ctx.strokePath()
ctx.setFillColor(black)
ctx.fillEllipse(in: CGRect(x: c.x - 100, y: c.y - 100, width: 200, height: 200))
ctx.setFillColor(white)
ctx.fillEllipse(in: CGRect(x: c.x - 58, y: c.y - 58, width: 40, height: 40))

// 右上那格插一支旗子
let fx = inner.minX + 24 + 2 * cell, fy = inner.minY + 24
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: fx + x * cell, y: fy + y * cell) }
ctx.setFillColor(black)
ctx.fill(CGRect(origin: p(0.22, 0.72), size: .init(width: cell * 0.56, height: cell * 0.09)))
ctx.fill(CGRect(origin: p(0.34, 0.64), size: .init(width: cell * 0.32, height: cell * 0.08)))
ctx.fill(CGRect(origin: p(0.5, 0.2), size: .init(width: cell * 0.07, height: cell * 0.46)))
ctx.setFillColor(rgb(1, 0, 0))
ctx.addLines(between: [p(0.57, 0.16), p(0.57, 0.5), p(0.22, 0.33)]); ctx.fillPath()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
