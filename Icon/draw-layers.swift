// Renders the icon layers for AppIcon.icon. Usage: swift Icon/draw-layers.swift <Assets dir>
import AppKit

let size = 1024
let out = URL(fileURLWithPath: CommandLine.arguments[1])

func render(_ name: String, _ draw: (CGContext) -> Void) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.displayP3)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, components: [r, g, b, a])!
}

render("bar.png") { ctx in
    ctx.addPath(CGPath(roundedRect: CGRect(x: 132, y: 417, width: 760, height: 190), cornerWidth: 95, cornerHeight: 95, transform: nil))
    ctx.setFillColor(color(0.96, 0.96, 0.98))
    ctx.fillPath()
}

render("dots.png") { ctx in
    ctx.setFillColor(color(0.17, 0.18, 0.24))
    for x in [628.0, 712.0] {
        ctx.fillEllipse(in: CGRect(x: x - 30, y: 482, width: 60, height: 60))
    }
    ctx.addPath(CGPath(roundedRect: CGRect(x: 772, y: 494, width: 70, height: 36), cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.fillPath()
}

render("cover.png") { ctx in
    let pill = CGPath(roundedRect: CGRect(x: 100, y: 377, width: 470, height: 270), cornerWidth: 135, cornerHeight: 135, transform: nil)
    ctx.saveGState()
    ctx.addPath(pill)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
                              colors: [color(0.47, 0.36, 1.0), color(1.0, 0.33, 0.62)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 647), end: CGPoint(x: 570, y: 377), options: [])
    ctx.restoreGState()

    // Crossed-out eye
    let center = CGPoint(x: 335, y: 512)
    ctx.setStrokeColor(color(1, 1, 1))
    ctx.setLineWidth(24)
    ctx.setLineCap(.round)
    let eye = CGMutablePath()
    eye.move(to: CGPoint(x: center.x - 115, y: center.y))
    eye.addQuadCurve(to: CGPoint(x: center.x + 115, y: center.y), control: CGPoint(x: center.x, y: center.y + 120))
    eye.addQuadCurve(to: CGPoint(x: center.x - 115, y: center.y), control: CGPoint(x: center.x, y: center.y - 120))
    ctx.addPath(eye)
    ctx.strokePath()
    ctx.setFillColor(color(1, 1, 1))
    ctx.fillEllipse(in: CGRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60))
    ctx.move(to: CGPoint(x: center.x - 95, y: center.y - 95))
    ctx.addLine(to: CGPoint(x: center.x + 95, y: center.y + 95))
    ctx.strokePath()
}
