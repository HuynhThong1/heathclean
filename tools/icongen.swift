import AppKit
import CoreGraphics
import CoreText
import Foundation

let size: CGFloat = 1024
let outDir = CommandLine.arguments[1]
let fontDir = CommandLine.arguments[2]

// Register the brand font so the monogram can use it.
for name in ["BeVietnamPro-ExtraBold", "BeVietnamPro-Bold"] {
    let url = URL(fileURLWithPath: "\(fontDir)/\(name).ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let fptBlue: UInt32 = 0x0062B0
let blue500: UInt32 = 0x1A7CCB
let fptOrange: UInt32 = 0xF37021
let fptGreen: UInt32 = 0x12B24C
let neutral50: UInt32 = 0xF8FAFC

func makeContext() -> CGContext {
    CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func write(_ ctx: CGContext, _ name: String) {
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(name).png")
}

func fillBrandGradient(_ ctx: CGContext) {
    // --gradient-brand: 120deg, blue → blue-500 → green
    let colors = [rgb(fptBlue), rgb(blue500), rgb(fptGreen)] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        // CSS puts the green stop at 130%; CGGradient only accepts 0…1, so the
        // gradient is truncated at 1 — the green never fully arrives, which is
        // what the web gradient looks like inside its box anyway.
        locations: [0, 0.55, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )
}

/// Three brand-coloured arcs forming a budget ring.
func drawRing(_ ctx: CGContext, radius: CGFloat, width: CGFloat, colors: [UInt32], alpha: CGFloat = 1, spans: [CGFloat] = [150, 96, 66]) {
    let center = CGPoint(x: size / 2, y: size / 2)
    // Sweep proportions echo the mark: blue leads, orange energizes, green grounds.
    let gap: CGFloat = 10
    var start: CGFloat = 90 // start at top, sweeping clockwise

    ctx.setLineCap(.round)
    ctx.setLineWidth(width)

    for (index, span) in spans.enumerated() {
        let a0 = (start - gap / 2) * .pi / 180
        let a1 = (start - span + gap / 2) * .pi / 180
        ctx.setStrokeColor(rgb(colors[index]).copy(alpha: alpha)!)
        ctx.beginPath()
        ctx.addArc(center: center, radius: radius, startAngle: a0, endAngle: a1, clockwise: true)
        ctx.strokePath()
        start -= span
    }
}

func drawGlyph(_ ctx: CGContext, _ text: String, fontName: String, pointSize: CGFloat, color: CGColor) {
    let font = CTFontCreateWithName(fontName as CFString, pointSize, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: -pointSize * 0.02
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(
        x: (size - bounds.width) / 2 - bounds.origin.x,
        y: (size - bounds.height) / 2 - bounds.origin.y
    )
    CTLineDraw(line, ctx)
}

// A — three-colour ring on the light page surface
do {
    let ctx = makeContext()
    ctx.setFillColor(rgb(neutral50))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    drawRing(ctx, radius: size * 0.30, width: size * 0.135,
             colors: [fptBlue, fptOrange, fptGreen])
    write(ctx, "icon-a-ring-light")
}

// B — light ring on the brand gradient
do {
    let ctx = makeContext()
    fillBrandGradient(ctx)
    drawRing(ctx, radius: size * 0.30, width: size * 0.135,
             colors: [0xFFFFFF, 0xFFFFFF, 0xFFFFFF], alpha: 0.28)
    drawRing(ctx, radius: size * 0.30, width: size * 0.135,
             colors: [0xFFFFFF, 0xFDD3B8, 0xBEECCE], alpha: 1)
    write(ctx, "icon-b-ring-gradient")
}

// C — monogram on the brand gradient
do {
    let ctx = makeContext()
    fillBrandGradient(ctx)
    drawGlyph(ctx, "H", fontName: "BeVietnamPro-ExtraBold",
              pointSize: size * 0.62, color: rgb(0xFFFFFF))
    write(ctx, "icon-c-monogram")
}

// D — ring wrapped around the monogram, on white
do {
    let ctx = makeContext()
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    // Thicker stroke and a longer green arc so both survive the 40pt tile.
    drawRing(ctx, radius: size * 0.345, width: size * 0.10,
             colors: [fptBlue, fptOrange, fptGreen], spans: [140, 96, 78])
    drawGlyph(ctx, "H", fontName: "BeVietnamPro-ExtraBold",
              pointSize: size * 0.42, color: rgb(fptBlue))
    write(ctx, "icon-d-ring-monogram")
}
