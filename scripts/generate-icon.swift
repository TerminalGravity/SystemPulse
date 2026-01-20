#!/usr/bin/env swift
import Cocoa

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

let iconsetPath = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, filename) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Draw gradient background with rounded corners
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) / 5.0
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradient from teal to green
    let gradient = NSGradient(colors: [
        NSColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1.0),
        NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
    ])!
    gradient.draw(in: path, angle: -45)

    // Draw bar chart
    let barColor = NSColor.white.withAlphaComponent(0.95)
    barColor.setFill()

    let margin = CGFloat(size) / 5.5
    let barWidth = (CGFloat(size) - margin * 2) / 6
    let gap = barWidth * 0.3
    let heights: [CGFloat] = [0.35, 0.55, 0.45, 0.75, 0.6]

    for (i, heightPct) in heights.enumerated() {
        let barX = margin + CGFloat(i) * (barWidth + gap)
        let barHeight = (CGFloat(size) - margin * 2) * heightPct
        let barY = margin

        let barRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2)
        barPath.fill()
    }

    image.unlockFocus()

    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "\(iconsetPath)/\(filename)")
        try? pngData.write(to: url)
    }
}

print("✓ Icons generated in \(iconsetPath)")
