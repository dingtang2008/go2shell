#!/usr/bin/swift
import Cocoa
import AppKit

// macOS HIG-compliant app icon:
// - 1024x1024 canvas, content inside the 824x824 grid (100pt padding per side)
// - Continuous-rounded "squircle" background with a dark vertical gradient
// - Terminal glyph centered on top in near-white

let canvas = CGSize(width: 1024, height: 1024)
let iconBounds = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185.4  // 22.5% of 824 — Apple's squircle ratio
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

// 1. Pre-render a tinted terminal glyph into its own bitmap so we can
//    composite it cleanly on top of the squircle (source-in against the
//    squircle background would tint the background too).
let glyphConfig = NSImage.SymbolConfiguration(pointSize: 500, weight: .medium, scale: .medium)
guard let glyph = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)?
        .withSymbolConfiguration(glyphConfig) else {
    print("❌ SF Symbol 'terminal' not available")
    exit(1)
}
let glyphSize = glyph.size

let tintedGlyph = NSImage(size: glyphSize)
tintedGlyph.lockFocus()
glyph.draw(in: NSRect(origin: .zero, size: glyphSize))
if let tctx = NSGraphicsContext.current?.cgContext {
    tctx.setBlendMode(.sourceIn)
    NSColor(white: 0.97, alpha: 1.0).setFill()
    NSRect(origin: .zero, size: glyphSize).fill()
}
tintedGlyph.unlockFocus()

// 2. Compose the final icon.
let image = NSImage(size: canvas)
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("❌ no CG context"); exit(1)
}

let bgPath = CGPath(roundedRect: iconBounds,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil)

// Squircle fill — dark charcoal gradient, top lighter than bottom.
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let bgColors = [
    NSColor(red: 0.23, green: 0.23, blue: 0.25, alpha: 1.0).cgColor,
    NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor
] as CFArray
let bgGradient = CGGradient(colorsSpace: srgb, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 512, y: iconBounds.maxY),
                       end: CGPoint(x: 512, y: iconBounds.minY),
                       options: [])
ctx.restoreGState()

// Soft top highlight for depth.
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let hiColors = [
    NSColor(white: 1.0, alpha: 0.14).cgColor,
    NSColor(white: 1.0, alpha: 0.0).cgColor
] as CFArray
let hiGradient = CGGradient(colorsSpace: srgb, colors: hiColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(hiGradient,
                       start: CGPoint(x: 512, y: iconBounds.maxY),
                       end: CGPoint(x: 512, y: iconBounds.maxY - 180),
                       options: [])
ctx.restoreGState()

// Hairline border for crispness against light backgrounds.
ctx.saveGState()
ctx.addPath(bgPath)
ctx.setStrokeColor(NSColor(white: 0.0, alpha: 0.35).cgColor)
ctx.setLineWidth(2)
ctx.strokePath()
ctx.restoreGState()

// Glyph on top, centered on the full canvas.
let glyphRect = NSRect(
    x: (canvas.width - glyphSize.width) / 2,
    y: (canvas.height - glyphSize.height) / 2,
    width: glyphSize.width,
    height: glyphSize.height
)
tintedGlyph.draw(in: glyphRect)

image.unlockFocus()

// 3. Persist.
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("❌ failed to encode PNG"); exit(1)
}
let out = URL(fileURLWithPath: "Resources/icon.png")
do {
    try png.write(to: out)
    print("✅ icon generated at \(out.path) (glyph \(glyphSize.width)x\(glyphSize.height))")
} catch {
    print("❌ write failed: \(error)"); exit(1)
}
