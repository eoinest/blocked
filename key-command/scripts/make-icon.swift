import AppKit

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
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels)/1024); transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 196, yRadius: 196)
        NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.35, alpha: 1).setFill(); tile.fill()
        let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
        shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -18)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        let key = NSBezierPath(roundedRect: NSRect(x: 153, y: 257, width: 718, height: 510), xRadius: 68, yRadius: 68)
        NSColor(calibratedRed: 0.76, green: 0.88, blue: 0.92, alpha: 1).setFill(); key.fill()
        NSGraphicsContext.restoreGraphicsState()
        let face = NSBezierPath(roundedRect: NSRect(x: 169, y: 290, width: 686, height: 465), xRadius: 57, yRadius: 57)
        NSColor(calibratedWhite: 0.98, alpha: 1).setFill(); face.fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 300, weight: .medium), .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.40, alpha: 1)]
        let text = "⌘" as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (1024-size.width)/2, y: 348), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
