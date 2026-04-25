import AppKit

/// Generates the CLIDE app icon programmatically — Clyde's face on a dark terminal background.
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

        // Background: rounded rectangle with dark terminal color
        let bgColor = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
        let bgPath = CGPath(roundedRect: rect.insetBy(dx: 20, dy: 20), cornerWidth: 80, cornerHeight: 80, transform: nil)
        ctx.addPath(bgPath)
        ctx.setFillColor(bgColor)
        ctx.fillPath()

        // Subtle border glow
        let goldColor = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.4)
        ctx.addPath(bgPath)
        ctx.setStrokeColor(goldColor)
        ctx.setLineWidth(3)
        ctx.strokePath()

        // Clyde's face — centered in the icon
        let faceWidth: CGFloat = 260
        let faceHeight: CGFloat = 200
        let faceX = (size - faceWidth) / 2
        let faceY: CGFloat = 220

        // Face box
        let faceRect = CGRect(x: faceX, y: faceY, width: faceWidth, height: faceHeight)
        let facePath = CGPath(roundedRect: faceRect, cornerWidth: 20, cornerHeight: 20, transform: nil)
        let faceBorder = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 0.8)
        ctx.addPath(facePath)
        ctx.setStrokeColor(faceBorder)
        ctx.setLineWidth(4)
        ctx.strokePath()

        // Eyes — two filled circles
        let eyeColor = CGColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1.0)
        let eyeRadius: CGFloat = 22
        let eyeY = faceY + faceHeight - 65

        // Left eye
        let leftEyeCenter = CGPoint(x: faceX + 75, y: eyeY)
        ctx.addEllipse(in: CGRect(x: leftEyeCenter.x - eyeRadius, y: leftEyeCenter.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2))
        ctx.setFillColor(eyeColor)
        ctx.fillPath()

        // Right eye
        let rightEyeCenter = CGPoint(x: faceX + faceWidth - 75, y: eyeY)
        ctx.addEllipse(in: CGRect(x: rightEyeCenter.x - eyeRadius, y: rightEyeCenter.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2))
        ctx.setFillColor(eyeColor)
        ctx.fillPath()

        // Eye pupils (dark circles inside)
        let pupilRadius: CGFloat = 8
        let pupilColor = CGColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1.0)
        ctx.addEllipse(in: CGRect(x: leftEyeCenter.x - pupilRadius + 4, y: leftEyeCenter.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2))
        ctx.setFillColor(pupilColor)
        ctx.fillPath()
        ctx.addEllipse(in: CGRect(x: rightEyeCenter.x - pupilRadius + 4, y: rightEyeCenter.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2))
        ctx.setFillColor(pupilColor)
        ctx.fillPath()

        // Mouth — a friendly curved line
        let mouthY = faceY + 45
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: faceX + 80, y: mouthY))
        mouthPath.addQuadCurve(to: CGPoint(x: faceX + faceWidth - 80, y: mouthY),
                                control: CGPoint(x: faceX + faceWidth / 2, y: mouthY - 30))
        ctx.addPath(mouthPath)
        ctx.setStrokeColor(eyeColor)
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.strokePath()

        // Antenna / connector from face to top
        let antennaX = size / 2
        let antennaBottom = faceY + faceHeight
        let antennaTop = faceY + faceHeight + 40
        ctx.move(to: CGPoint(x: antennaX, y: antennaBottom))
        ctx.addLine(to: CGPoint(x: antennaX, y: antennaTop))
        ctx.setStrokeColor(faceBorder)
        ctx.setLineWidth(4)
        ctx.strokePath()

        // Antenna dot
        ctx.addEllipse(in: CGRect(x: antennaX - 8, y: antennaTop, width: 16, height: 16))
        ctx.setFillColor(eyeColor)
        ctx.fillPath()

        // "CLIDE" text at the bottom
        let textY: CGFloat = 130
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 52, weight: .bold),
            .foregroundColor: NSColor(cgColor: eyeColor) ?? NSColor.yellow,
            .paragraphStyle: paragraphStyle,
        ]

        let textRect = CGRect(x: 0, y: textY - 30, width: size, height: 70)
        "CLIDE".draw(in: textRect, withAttributes: attrs)

        // Subtitle
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor(red: 0.545, green: 0.580, blue: 0.620, alpha: 1.0),
            .paragraphStyle: paragraphStyle,
        ]
        let subRect = CGRect(x: 0, y: textY - 55, width: size, height: 30)
        "CLI Dev Environment".draw(in: subRect, withAttributes: subAttrs)

        image.unlockFocus()
        return image
    }

    static func setAsAppIcon() {
        NSApp.applicationIconImage = generate()
    }
}
