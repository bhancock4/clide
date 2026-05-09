#!/usr/bin/env swift
// Generates 8 icon candidate PNGs for CLIDE app icon selection.
// Usage: swift scripts/icon-candidates.swift [output-dir]
// Drawing code based on Sources/AppKit/AppIcon.swift

import AppKit

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dist/icon-candidates"

// MARK: - Shared drawing helpers

func makeContext(size: CGFloat) -> (NSImage, CGContext)? {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return nil
    }
    return (image, ctx)
}

func drawBackground(_ ctx: CGContext, size: CGFloat, bgColor: CGColor, cornerRadius: CGFloat = 80) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: 20, dy: 20),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(bgColor)
    ctx.fillPath()
}

func drawGlow(_ ctx: CGContext, size: CGFloat, color: CGColor) {
    let center = CGPoint(x: size / 2, y: size / 2 - 10)
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [color, CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray,
                                  locations: [0, 1]) {
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: 200, options: [])
    }
}

let cGrid: [[Bool]] = [
    [false, true, true, true, true, true],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [false, true, true, true, true, true],
]

func drawCBlocks(_ ctx: CGContext, color: CGColor, outlineColor: CGColor? = nil,
                 gridLeft: CGFloat = 115, gridBottom: CGFloat = 75,
                 blockW: CGFloat = 44, blockH: CGFloat = 52,
                 stepX: CGFloat = 36, stepY: CGFloat = 42,
                 fill: Bool = true, strokeWidth: CGFloat = 1.5) {
    for (row, cols) in cGrid.enumerated() {
        for (col, filled) in cols.enumerated() {
            guard filled else { continue }
            let x = gridLeft + CGFloat(col) * stepX
            let y = gridBottom + CGFloat(row) * stepY
            let blockRect = CGRect(x: x, y: y, width: blockW, height: blockH)
            let path = CGPath(roundedRect: blockRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            if let outline = outlineColor {
                ctx.addPath(path)
                ctx.setStrokeColor(outline)
                ctx.setLineWidth(strokeWidth)
                ctx.strokePath()
            }
            if fill {
                ctx.addPath(path)
                ctx.setFillColor(color)
                ctx.fillPath()
            }
        }
    }
}

func drawCStroke(_ ctx: CGContext, color: CGColor,
                 gridLeft: CGFloat = 115, gridBottom: CGFloat = 75,
                 blockW: CGFloat = 44, blockH: CGFloat = 52,
                 stepX: CGFloat = 36, stepY: CGFloat = 42,
                 lineWidth: CGFloat = 5) {
    for (row, cols) in cGrid.enumerated() {
        for (col, filled) in cols.enumerated() {
            guard filled else { continue }
            let x = gridLeft + CGFloat(col) * stepX
            let y = gridBottom + CGFloat(row) * stepY
            let blockRect = CGRect(x: x, y: y, width: blockW, height: blockH)
            let path = CGPath(roundedRect: blockRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(path)
            ctx.setStrokeColor(color)
            ctx.setLineWidth(lineWidth)
            ctx.strokePath()
        }
    }
}

func drawEyes(_ ctx: CGContext, gridBottom: CGFloat = 75, gridLeft: CGFloat = 115,
              stepX: CGFloat = 36, stepY: CGFloat = 42, blockH: CGFloat = 52,
              blockW: CGFloat = 44, eyeColor: CGColor? = nil, pupilColor: CGColor? = nil) {
    let eyeRadius: CGFloat = 20
    let pupilRadius: CGFloat = 9
    let topRowY = gridBottom + 6 * stepY + blockH
    let eyeY = topRowY + eyeRadius + 4
    let eyeLeftX = gridLeft + 2 * stepX + blockW / 2
    let eyeRightX = gridLeft + 3.5 * stepX + blockW / 2

    let white = eyeColor ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    let dark = pupilColor ?? CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)

    for ex in [eyeLeftX, eyeRightX] {
        ctx.addEllipse(in: CGRect(x: ex - eyeRadius, y: eyeY - eyeRadius,
                                   width: eyeRadius * 2, height: eyeRadius * 2))
        ctx.setFillColor(white)
        ctx.fillPath()
    }
    for ex in [eyeLeftX, eyeRightX] {
        ctx.addEllipse(in: CGRect(x: ex - pupilRadius + 4, y: eyeY - pupilRadius - 2,
                                   width: pupilRadius * 2, height: pupilRadius * 2))
        ctx.setFillColor(dark)
        ctx.fillPath()
    }
}

func drawBorderGlow(_ ctx: CGContext, size: CGFloat, color: CGColor, cornerRadius: CGFloat = 80) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: 20, dy: 20),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG for \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// MARK: - Color constants

let darkBg = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
let gold = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1.0)
let goldGlow = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.12)
let goldOutline = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.3)
let goldBorder = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.3)

let size: CGFloat = 512

// MARK: - Variant 1: Current design (baseline)

func variant1() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    drawBackground(ctx, size: size, bgColor: darkBg)
    drawGlow(ctx, size: size, color: goldGlow)
    drawCBlocks(ctx, color: gold, outlineColor: goldOutline)
    drawEyes(ctx)
    drawBorderGlow(ctx, size: size, color: goldBorder)
    image.unlockFocus()
    return image
}

// MARK: - Variant 2: Deeper corners + drop shadow

func variant2() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }

    // Drop shadow behind the rounded rect
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
    drawBackground(ctx, size: size, bgColor: darkBg, cornerRadius: 120)
    ctx.setShadow(offset: .zero, blur: 0)

    drawGlow(ctx, size: size, color: goldGlow)
    drawCBlocks(ctx, color: gold, outlineColor: goldOutline)
    drawEyes(ctx)
    drawBorderGlow(ctx, size: size, color: goldBorder, cornerRadius: 120)
    image.unlockFocus()
    return image
}

// MARK: - Variant 3: Gradient gold (lighter top to darker bottom)

func variant3() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    drawBackground(ctx, size: size, bgColor: darkBg)
    drawGlow(ctx, size: size, color: goldGlow)

    let lightGold = CGColor(red: 0.92, green: 0.80, blue: 0.35, alpha: 1.0)
    let darkGold = CGColor(red: 0.60, green: 0.42, blue: 0.08, alpha: 1.0)

    // Draw C with gradient by clipping
    ctx.saveGState()
    // Build a path from all the C blocks
    for (row, cols) in cGrid.enumerated() {
        for (col, filled) in cols.enumerated() {
            guard filled else { continue }
            let x: CGFloat = 115 + CGFloat(col) * 36
            let y: CGFloat = 75 + CGFloat(row) * 42
            let blockRect = CGRect(x: x, y: y, width: 44, height: 52)
            ctx.addRect(blockRect)
        }
    }
    ctx.clip()
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [darkGold, lightGold] as CFArray,
                                  locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 75),
                               end: CGPoint(x: 0, y: 75 + 6 * 42 + 52), options: [])
    }
    ctx.restoreGState()

    // Block outlines on top
    let outlineColor = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.4)
    drawCBlocks(ctx, color: .clear, outlineColor: outlineColor, fill: false)

    drawEyes(ctx)
    drawBorderGlow(ctx, size: size, color: goldBorder)
    image.unlockFocus()
    return image
}

// MARK: - Variant 4: Minimal — no eyes, clean geometric C

func variant4() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    drawBackground(ctx, size: size, bgColor: darkBg)

    // No glow — clean minimal look
    drawCBlocks(ctx, color: gold, outlineColor: nil)
    // No eyes
    drawBorderGlow(ctx, size: size, color: goldBorder)
    image.unlockFocus()
    return image
}

// MARK: - Variant 5: Terminal-style — green on black with scanlines

func variant5() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    let black = CGColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0)
    let green = CGColor(red: 0.0, green: 0.85, blue: 0.2, alpha: 1.0)
    let greenGlow = CGColor(red: 0.0, green: 0.85, blue: 0.2, alpha: 0.15)
    let greenBorder = CGColor(red: 0.0, green: 0.85, blue: 0.2, alpha: 0.3)
    let greenOutline = CGColor(red: 0.0, green: 0.85, blue: 0.2, alpha: 0.3)

    drawBackground(ctx, size: size, bgColor: black)
    drawGlow(ctx, size: size, color: greenGlow)
    drawCBlocks(ctx, color: green, outlineColor: greenOutline)

    // Scanlines
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.15))
    var y: CGFloat = 20
    while y < size - 20 {
        ctx.fill(CGRect(x: 20, y: y, width: size - 40, height: 1))
        y += 3
    }

    drawEyes(ctx, eyeColor: green, pupilColor: black)
    drawBorderGlow(ctx, size: size, color: greenBorder)
    image.unlockFocus()
    return image
}

// MARK: - Variant 6: Outlined C (no fill, thick gold stroke) with eyes

func variant6() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    drawBackground(ctx, size: size, bgColor: darkBg)
    drawGlow(ctx, size: size, color: goldGlow)

    drawCStroke(ctx, color: gold, lineWidth: 4)
    drawEyes(ctx)
    drawBorderGlow(ctx, size: size, color: goldBorder)
    image.unlockFocus()
    return image
}

// MARK: - Variant 7: Larger C, bolder blocks filling more frame

func variant7() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    drawBackground(ctx, size: size, bgColor: darkBg)
    drawGlow(ctx, size: size, color: goldGlow)

    // Bigger blocks, shifted to fill more of the icon
    let bW: CGFloat = 56
    let bH: CGFloat = 64
    let sX: CGFloat = 46
    let sY: CGFloat = 52
    let gL: CGFloat = 85
    let gB: CGFloat = 40
    let outline = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.3)

    drawCBlocks(ctx, color: gold, outlineColor: outline,
                gridLeft: gL, gridBottom: gB, blockW: bW, blockH: bH, stepX: sX, stepY: sY)
    drawEyes(ctx, gridBottom: gB, gridLeft: gL, stepX: sX, stepY: sY, blockH: bH, blockW: bW)
    drawBorderGlow(ctx, size: size, color: goldBorder)
    image.unlockFocus()
    return image
}

// MARK: - Variant 8: Inverted — gold background, dark C

func variant8() -> NSImage {
    guard let (image, ctx) = makeContext(size: size) else { return NSImage() }
    drawBackground(ctx, size: size, bgColor: gold)

    // Subtle darker gold glow
    let darkGoldGlow = CGColor(red: 0.6, green: 0.45, blue: 0.05, alpha: 0.2)
    drawGlow(ctx, size: size, color: darkGoldGlow)

    let darkC = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
    let darkOutline = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 0.3)
    drawCBlocks(ctx, color: darkC, outlineColor: darkOutline)
    drawEyes(ctx, eyeColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
             pupilColor: gold)

    let darkBorder = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 0.3)
    drawBorderGlow(ctx, size: size, color: darkBorder)
    image.unlockFocus()
    return image
}

// MARK: - Generate all

let variants: [(String, () -> NSImage)] = [
    ("1-baseline", variant1),
    ("2-deep-corners-shadow", variant2),
    ("3-gradient-gold", variant3),
    ("4-minimal-no-eyes", variant4),
    ("5-terminal-green", variant5),
    ("6-outlined-stroke", variant6),
    ("7-larger-bolder", variant7),
    ("8-inverted-gold-bg", variant8),
]

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for (name, generator) in variants {
    let image = generator()
    savePNG(image, to: "\(outputDir)/icon-\(name).png")
}

print("\nDone! \(variants.count) icons saved to \(outputDir)/")
