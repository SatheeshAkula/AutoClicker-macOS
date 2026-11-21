import AppKit

func generateIcon(outputPath: String) {
    let size: CGFloat = 1024
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        exit(1)
    }

    // Clear transparent background
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Squircle dimensions according to Apple macOS HIG
    let margin: CGFloat = 100
    let squircleRect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let cornerRadius: CGFloat = 185

    // Soft drop shadow beneath squircle
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 36, color: NSColor.black.withAlphaComponent(0.40).cgColor)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.black.setFill()
    squirclePath.fill()
    ctx.restoreGState()

    // Base Squircle Background with rich multi-stop gradient
    ctx.saveGState()
    squirclePath.addClip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        NSColor(red: 0.05, green: 0.12, blue: 0.28, alpha: 1.0).cgColor, // Midnight Navy
        NSColor(red: 0.08, green: 0.25, blue: 0.60, alpha: 1.0).cgColor, // Deep Royal Blue
        NSColor(red: 0.14, green: 0.45, blue: 0.90, alpha: 1.0).cgColor, // Vibrant Blue
        NSColor(red: 0.25, green: 0.60, blue: 1.00, alpha: 1.0).cgColor  // Electric Cyan Highlight
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 0.40, 0.80, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
            end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
            options: []
        )
    }

    // Top inner glass edge highlight
    let innerHighlight = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 2.5, dy: 2.5), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
    NSColor.white.withAlphaComponent(0.28).setStroke()
    innerHighlight.lineWidth = 4.5
    innerHighlight.stroke()

    // Radiant click ripple circles (Auto-click pulse motif)
    let center = CGPoint(x: 512, y: 512)
    let rings: [(radius: CGFloat, alpha: CGFloat, width: CGFloat)] = [
        (290, 0.12, 10),
        (220, 0.20, 12),
        (145, 0.32, 14),
        (75,  0.48, 16)
    ]
    for ring in rings {
        let ringRect = CGRect(x: center.x - ring.radius, y: center.y - ring.radius, width: ring.radius * 2, height: ring.radius * 2)
        let ringPath = NSBezierPath(ovalIn: ringRect)
        NSColor(red: 0.4, green: 0.9, blue: 1.0, alpha: ring.alpha).setStroke()
        ringPath.lineWidth = ring.width
        ringPath.stroke()
    }

    // Draw high-res SF Symbol cursor arrow with rays
    let config = NSImage.SymbolConfiguration(pointSize: 440, weight: .bold)
        .applying(.init(paletteColors: [
            NSColor.white,
            NSColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1.0),
            NSColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1.0)
        ]))

    if let symbol = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let symbolRect = CGRect(x: 236, y: 236, width: 540, height: 540)
        symbol.draw(in: symbolRect)
    }

    // Subtle lightning/fast automation badge in top-right
    let lightningConfig = NSImage.SymbolConfiguration(pointSize: 120, weight: .bold)
        .applying(.init(paletteColors: [NSColor(red: 1.0, green: 0.82, blue: 0.18, alpha: 0.95)]))
    if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(lightningConfig) {
        let boltRect = CGRect(x: 690, y: 690, width: 140, height: 140)
        bolt.draw(in: boltRect)
    }

    ctx.restoreGState()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        exit(2)
    }

    try? png.write(to: URL(fileURLWithPath: outputPath))
}

let args = CommandLine.arguments
let output = args.count > 1 ? args[1] : "AppIcon_1024.png"
generateIcon(outputPath: output)
print("Generated master icon: \(output)")
