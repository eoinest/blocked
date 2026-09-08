import AppKit

// Original vector artwork, rasterized at every macOS icon size.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 196, yRadius: 196)
        NSColor(calibratedWhite: 0.87, alpha: 1).setFill(); tile.fill()
        let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.20)
        shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -18)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        let key = NSBezierPath(roundedRect: NSRect(x: 134, y: 251, width: 756, height: 520), xRadius: 62, yRadius: 62)
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill(); key.fill()
        NSGraphicsContext.restoreGraphicsState()
        let face = NSBezierPath(roundedRect: NSRect(x: 151, y: 285, width: 722, height: 475), xRadius: 49, yRadius: 49)
        NSColor.white.setFill(); face.fill()
        let label = points >= 32 ? "blocked" : "b"
        let font = NSFont.systemFont(ofSize: points >= 32 ? 128 : 235, weight: .regular)
        (label as NSString).draw(at: NSPoint(x: 210, y: 340), withAttributes: [.font: font, .foregroundColor: NSColor(calibratedWhite: 0.43, alpha: 1)])
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
