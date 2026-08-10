import AppKit
import Foundation

// App icons must have no alpha channel — Xcode/App Store reject transparency.
let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]

let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(src, 0, nil)!

let width = image.width
let height = image.height

let ctx = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

let out = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: out)
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: output))
print("wrote \(output) — \(width)x\(height), alpha: \(out.alphaInfo == .none ? "none" : "skipped")")
