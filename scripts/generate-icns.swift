#!/usr/bin/env swift
// Generates CLIDE app icon as .icns file.
// Drawing code based on Sources/AppKit/AppIcon.swift (variant 3: gradient gold)
// Usage: swift scripts/generate-icns.swift <output.icns>

import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift generate-icns.swift <output.icns>")
    exit(1)
}

let outputPath = CommandLine.arguments[1]

// MARK: - Icon drawing (gradient gold variant)

let cGrid: [[Bool]] = [
    [false, true, true, true, true, true],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [true,  true, false, false, false, false],
    [false, true, true, true, true, true],
]

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let scale = size / 512.0
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Background
    let darkBg = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: 20 * scale, dy: 20 * scale),
                        cornerWidth: 80 * scale, cornerHeight: 80 * scale, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(darkBg)
    ctx.fillPath()

    // Subtle gold glow
    let goldGlow = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.12)
    let center = CGPoint(x: size / 2, y: size / 2 - 10 * scale)
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [goldGlow, CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray,
                                  locations: [0, 1]) {
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: 200 * scale, options: [])
    }

    // Scaled block dimensions
    let blockW: CGFloat = 44 * scale
    let blockH: CGFloat = 52 * scale
    let stepX: CGFloat = 36 * scale
    let stepY: CGFloat = 42 * scale
    let gridLeft: CGFloat = 115 * scale
    let gridBottom: CGFloat = 75 * scale

    // Draw C with gradient (lighter top to darker bottom)
    let lightGold = CGColor(red: 0.92, green: 0.80, blue: 0.35, alpha: 1.0)
    let darkGold = CGColor(red: 0.60, green: 0.42, blue: 0.08, alpha: 1.0)

    ctx.saveGState()
    for (row, cols) in cGrid.enumerated() {
        for (col, filled) in cols.enumerated() {
            guard filled else { continue }
            let x = gridLeft + CGFloat(col) * stepX
            let y = gridBottom + CGFloat(row) * stepY
            ctx.addRect(CGRect(x: x, y: y, width: blockW, height: blockH))
        }
    }
    ctx.clip()
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [darkGold, lightGold] as CFArray,
                                  locations: [0, 1]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: gridBottom),
                               end: CGPoint(x: 0, y: gridBottom + 6 * stepY + blockH),
                               options: [])
    }
    ctx.restoreGState()

    // Block outlines
    let outlineColor = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.4)
    for (row, cols) in cGrid.enumerated() {
        for (col, filled) in cols.enumerated() {
            guard filled else { continue }
            let x = gridLeft + CGFloat(col) * stepX
            let y = gridBottom + CGFloat(row) * stepY
            let blockRect = CGRect(x: x, y: y, width: blockW, height: blockH)
            let path = CGPath(roundedRect: blockRect, cornerWidth: 4 * scale, cornerHeight: 4 * scale, transform: nil)
            ctx.addPath(path)
            ctx.setStrokeColor(outlineColor)
            ctx.setLineWidth(1.5 * scale)
            ctx.strokePath()
        }
    }

    // Eyes
    let eyeRadius: CGFloat = 20 * scale
    let pupilRadius: CGFloat = 9 * scale
    let topRowY = gridBottom + 6 * stepY + blockH
    let eyeY = topRowY + eyeRadius + 4 * scale
    let eyeLeftX = gridLeft + 2 * stepX + blockW / 2
    let eyeRightX = gridLeft + 3.5 * stepX + blockW / 2
    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

    for ex in [eyeLeftX, eyeRightX] {
        ctx.addEllipse(in: CGRect(x: ex - eyeRadius, y: eyeY - eyeRadius,
                                   width: eyeRadius * 2, height: eyeRadius * 2))
        ctx.setFillColor(white)
        ctx.fillPath()
    }
    for ex in [eyeLeftX, eyeRightX] {
        ctx.addEllipse(in: CGRect(x: ex - pupilRadius + 4 * scale, y: eyeY - pupilRadius - 2 * scale,
                                   width: pupilRadius * 2, height: pupilRadius * 2))
        ctx.setFillColor(darkBg)
        ctx.fillPath()
    }

    // Border glow
    let borderGlow = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.3)
    ctx.addPath(bgPath)
    ctx.setStrokeColor(borderGlow)
    ctx.setLineWidth(2 * scale)
    ctx.strokePath()

    image.unlockFocus()
    return image
}

// MARK: - Generate .iconset and convert to .icns

let fm = FileManager.default
let tempDir = NSTemporaryDirectory()
let iconsetPath = "\(tempDir)CLIDE.iconset"
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Required sizes: name -> pixel size
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in sizes {
    let icon = renderIcon(size: px)
    guard let tiff = icon.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to render \(name)")
        exit(1)
    }
    let path = "\(iconsetPath)/\(name)"
    try png.write(to: URL(fileURLWithPath: path))
}

// Convert .iconset to .icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", outputPath, iconsetPath]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Generated: \(outputPath)")
} else {
    print("iconutil failed with status \(process.terminationStatus)")
    exit(1)
}

// Cleanup
try? fm.removeItem(atPath: iconsetPath)
