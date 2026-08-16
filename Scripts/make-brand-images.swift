#!/usr/bin/env swift
//
// Renders the brand artwork BRAND_SPEC §1 and §2 ask for as flat files:
// three 1024×1024 app icons and the launch screen's bowl.
//
//   swift Scripts/make-brand-images.swift
//
// Why a script rather than exported PNGs checked in by hand: the icons and the
// launch image are the *same geometry* as `BrandMark.swift`, at other sizes. A
// hand-exported file drifts the moment the mark is touched and nothing says so;
// this can be re-run.
//
// The paths below mirror `BowlMark` / `DomeArc`. They are duplicated because a
// script cannot import the app module — **if the mark changes, both change.**
// The arc directions are the corrected ones: the bowl sweeps `clockwise: true`
// so it passes 90° (screen bottom) in the y-down space this draws in, which is
// the one place BRAND_SPEC's own Swift snippet is wrong.

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Geometry, on the 24×24 grid

func bowlPath(scale s: CGFloat) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 3 * s, y: 13 * s))
    path.addArc(
        center: CGPoint(x: 12 * s, y: 13 * s), radius: 9 * s,
        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true
    )
    path.closeSubpath()
    return path
}

func domePath(scale s: CGFloat) -> Path {
    var path = Path()
    path.addArc(
        center: CGPoint(x: 12 * s, y: 13 * s), radius: 8.2 * s,
        startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false
    )
    return path
}

let domeLineWidthRatio: CGFloat = 2.6 / 24
/// The bowl spans x 3…21 of the grid: eighteen units wide, nine tall.
let bowlBox = CGRect(x: 3, y: 13, width: 18, height: 9)

// MARK: - Drawing

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// `alpha: false` gives an opaque bitmap, which is what an app icon must be —
/// the App Store rejects one with an alpha channel and iOS applies its own mask.
func makeContext(width: Int, height: Int, alpha: Bool) -> CGContext {
    let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue
    )!
    // Flip to a y-down space so the grid coordinates above read the same way they
    // do in SwiftUI. Without this every arc comes out mirrored.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    return context
}

func write(_ context: CGContext, to url: URL) {
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL, UTType.png.identifier as CFString, 1, nil
          )
    else { fatalError("could not encode \(url.lastPathComponent)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("could not write \(url.lastPathComponent)")
    }
    print("  \(url.lastPathComponent)")
}

/// Draws the whole mark — bowl and dome — into a square box of `side`, with its
/// top-left at `origin`.
func drawMark(in context: CGContext, origin: CGPoint, side: CGFloat, color markColor: CGColor) {
    context.saveGState()
    context.translateBy(x: origin.x, y: origin.y)
    let s = side / 24
    context.addPath(bowlPath(scale: s).cgPath)
    context.setFillColor(markColor)
    context.fillPath()
    context.addPath(domePath(scale: s).cgPath)
    context.setStrokeColor(markColor)
    context.setLineWidth(domeLineWidthRatio * side)
    context.setLineCap(.round)
    context.strokePath()
    context.restoreGState()
}

// MARK: - App icons (§1)

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSet = root.appending(path: "App/Resources/Assets.xcassets/AppIcon.appiconset")
let side: CGFloat = 1024

print("app icons →")

// Light: flat brand blue, mark white at 62% of the side.
do {
    let context = makeContext(width: 1024, height: 1024, alpha: false)
    context.setFillColor(color(0x0062B0))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    let markSide = 0.62 * side
    drawMark(
        in: context,
        origin: CGPoint(x: (side - markSide) / 2, y: (side - markSide) / 2),
        side: markSide, color: color(0xFFFFFF)
    )
    write(context, to: iconSet.appending(path: "AppIcon-1024.png"))
}

// Dark: the page colour, a brand-blue disc at 74%, mark white at 50%.
do {
    let context = makeContext(width: 1024, height: 1024, alpha: false)
    context.setFillColor(color(0x0B1219))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    let discSide = 0.74 * side
    context.setFillColor(color(0x0062B0))
    context.fillEllipse(
        in: CGRect(x: (side - discSide) / 2, y: (side - discSide) / 2,
                   width: discSide, height: discSide)
    )
    let markSide = 0.50 * side
    drawMark(
        in: context,
        origin: CGPoint(x: (side - markSide) / 2, y: (side - markSide) / 2),
        side: markSide, color: color(0xFFFFFF)
    )
    write(context, to: iconSet.appending(path: "AppIcon-Dark-1024.png"))
}

// Tinted: luminosity only — iOS applies the user's tint to this, so it carries no
// colour of its own.
do {
    let context = makeContext(width: 1024, height: 1024, alpha: false)
    context.setFillColor(color(0x1C1C1E))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    let markSide = 0.62 * side
    drawMark(
        in: context,
        origin: CGPoint(x: (side - markSide) / 2, y: (side - markSide) / 2),
        side: markSide, color: color(0xF2F2F2)
    )
    write(context, to: iconSet.appending(path: "AppIcon-Tinted-1024.png"))
}

// MARK: - Launch bowl (§2)

// The launch screen draws the bowl **alone**, 112pt wide, over a brand-blue
// background — at frame 0 of the splash the dome and the wordmark are invisible,
// so they are not in the image. This one keeps its alpha: it is composited over
// the storyboard's background colour, not over nothing.
print("launch image →")
let bowlSet = root.appending(path: "App/Resources/Assets.xcassets/LaunchBowl.imageset")
try? FileManager.default.createDirectory(at: bowlSet, withIntermediateDirectories: true)

for scale in [1, 2, 3] {
    let width = 112 * CGFloat(scale)
    let unit = width / bowlBox.width          // points per grid unit
    let height = bowlBox.height * unit
    let context = makeContext(width: Int(width), height: Int(height), alpha: true)
    context.translateBy(x: -bowlBox.minX * unit, y: -bowlBox.minY * unit)
    context.addPath(bowlPath(scale: unit).cgPath)
    context.setFillColor(color(0xFFFFFF))
    context.fillPath()
    let suffix = scale == 1 ? "" : "@\(scale)x"
    write(context, to: bowlSet.appending(path: "LaunchBowl\(suffix).png"))
}

print("done")
