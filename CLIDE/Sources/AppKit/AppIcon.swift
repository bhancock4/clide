import AppKit

/// Generates the CLIDE app icon — pixel-block golden C with Clippy-style eyes.
enum AppIcon {

    static func generate() -> NSImage {
        let size: CGFloat = 512
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let rect = CGRect(x: 0, y: 0, width: size, height: size)

        // Background
        let bgColor = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
        let bgPath = CGPath(roundedRect: rect.insetBy(dx: 20, dy: 20), cornerWidth: 80, cornerHeight: 80, transform: nil)
        ctx.addPath(bgPath)
        ctx.setFillColor(bgColor)
        ctx.fillPath()

        // Subtle gold glow
        let glowColor = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.12)
        let glowCenter = CGPoint(x: size / 2, y: size / 2 - 10)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [glowColor, CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray,
                                      locations: [0, 1]) {
            ctx.drawRadialGradient(gradient, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: 200, options: [])
        }

        let gold = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1.0)
        let darkBg = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)

        // Draw C as a grid of small blocks — like the ASCII ██ characters
        // Overlapping rectangles forming a C — like the block-character font
        // Each block overlaps its neighbor slightly, creating the thick stacked look
        let blockW: CGFloat = 44
        let blockH: CGFloat = 52
        let stepX: CGFloat = 36   // less than blockW → horizontal overlap
        let stepY: CGFloat = 42   // less than blockH → vertical overlap

        let gridLeft: CGFloat = 115
        let gridBottom: CGFloat = 75

        // C shape as a boolean grid (row 0 = bottom, row 6 = top)
        let cGrid: [[Bool]] = [
            [false, true, true, true, true, true],  // row 0 (bottom bar)
            [true,  true, false, false, false, false], // row 1
            [true,  true, false, false, false, false], // row 2
            [true,  true, false, false, false, false], // row 3
            [true,  true, false, false, false, false], // row 4
            [true,  true, false, false, false, false], // row 5
            [false, true, true, true, true, true],  // row 6 (top bar)
        ]

        // Draw with subtle dark outlines for the overlapping effect
        let outline = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.3)
        for (row, cols) in cGrid.enumerated() {
            for (col, filled) in cols.enumerated() {
                guard filled else { continue }
                let x = gridLeft + CGFloat(col) * stepX
                let y = gridBottom + CGFloat(row) * stepY
                let blockRect = CGRect(x: x, y: y, width: blockW, height: blockH)
                let path = CGPath(roundedRect: blockRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
                // Dark border to show individual blocks within the overlap
                ctx.addPath(path)
                ctx.setStrokeColor(outline)
                ctx.setLineWidth(1.5)
                ctx.strokePath()
                // Gold fill
                ctx.addPath(path)
                ctx.setFillColor(gold)
                ctx.fillPath()
            }
        }

        // Eyes — white circles with dark pupils, sitting on top of the C
        let eyeRadius: CGFloat = 20
        let pupilRadius: CGFloat = 9
        let topRowY = gridBottom + 6 * stepY + blockH
        let eyeY = topRowY + eyeRadius + 4
        let eyeLeftX = gridLeft + 2 * stepX + blockW / 2
        let eyeRightX = gridLeft + 3.5 * stepX + blockW / 2

        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        for ex in [eyeLeftX, eyeRightX] {
            ctx.addEllipse(in: CGRect(x: ex - eyeRadius, y: eyeY - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2))
            ctx.setFillColor(white)
            ctx.fillPath()
        }

        for ex in [eyeLeftX, eyeRightX] {
            ctx.addEllipse(in: CGRect(x: ex - pupilRadius + 4, y: eyeY - pupilRadius - 2, width: pupilRadius * 2, height: pupilRadius * 2))
            ctx.setFillColor(darkBg)
            ctx.fillPath()
        }

        // Border glow
        let borderGlow = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.3)
        ctx.addPath(bgPath)
        ctx.setStrokeColor(borderGlow)
        ctx.setLineWidth(2)
        ctx.strokePath()

        image.unlockFocus()
        return image
    }

    static func setAsAppIcon() {
        NSApp.applicationIconImage = generate()
    }
}
