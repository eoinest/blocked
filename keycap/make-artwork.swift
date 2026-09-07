// Run on macOS: swift keycap/make-artwork.swift
// Renders seven letters using the installed macOS font. No font files embedded.
import Foundation
import CoreText
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let fontURL = URL(fileURLWithPath: "/System/Library/Fonts/SFCompact.ttf")
let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor]
guard let descriptor = descriptors.first(where: {
    (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String) == ".SFCompact-Regular"
}) else { fatalError("Installed SF Compact Regular was not found; do not silently substitute.") }
let font = CTFontCreateWithFontDescriptor(descriptor, 100, nil)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "blocked", attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font
]))
let letters = CGMutablePath()
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let n = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: n)
    var positions = [CGPoint](repeating: .zero, count: n)
    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
    CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
    for i in 0..<n {
        guard let glyph = CTFontCreatePathForGlyph(font, glyphs[i], nil) else { fatalError("Missing glyph") }
        letters.addPath(glyph, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
    }
}
let box = letters.boundingBoxOfPath
let scale = 900 / box.width // 9 mm at 100 px/mm
let width = 2700, height = 1800
// Visual Apple-style gray approximation; not a manufacturer ink specification.
let inkHex = "#6E6E73"
let inkRGB: [CGFloat] = [110.0/255, 110.0/255, 115.0/255, 1]
// SVG y grows down. Artwork's ink bounds have exactly 2 mm left/bottom inset.
var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
    tx: 200 - box.minX * scale, ty: 1600 + box.minY * scale)
let artwork = letters.copy(using: &transform)!
func number(_ n: CGFloat) -> String { String(format: "%.4f", Double(n)) }
func point(_ p: CGPoint) -> String { "\(number(p.x)) \(number(p.y))" }
var commands: [String] = []
artwork.applyWithBlock { ptr in
    let e = ptr.pointee
    switch e.type {
    case .moveToPoint: commands.append("M" + point(e.points[0]))
    case .addLineToPoint: commands.append("L" + point(e.points[0]))
    case .addQuadCurveToPoint: commands.append("Q" + point(e.points[0]) + " " + point(e.points[1]))
    case .addCurveToPoint: commands.append("C" + point(e.points[0]) + " " + point(e.points[1]) + " " + point(e.points[2]))
    case .closeSubpath: commands.append("Z")
    @unknown default: fatalError("Unknown path command")
    }
}
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="27mm" height="18mm" viewBox="0 0 2700 1800">
<title>blocked — SF Compact Regular, lower-left Tab keycap artwork</title>
<desc>Transparent nominal placement canvas, not a keycap dimensional drawing. Cool-gray legend (#6E6E73, visual approximation) 9 mm wide, 2 mm from left and bottom. Preserve placement; confirm on vendor proof. Lettering is paths, no embedded font.</desc>
<path fill="\(inkHex)" d="\(commands.joined(separator: " "))"/>
</svg>
"""
try svg.write(to: output.appendingPathComponent("blocked-tab-upload.svg"), atomically: true, encoding: .utf8)
func render(filename: String, preview: Bool) throws {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
    if preview {
        ctx.setFillColor(CGColor(gray: 0.92, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.addPath(CGPath(roundedRect: CGRect(x: 30, y: 30, width: width-60, height: height-60), cornerWidth: 110, cornerHeight: 110, transform: nil))
        ctx.fillPath()
    }
    ctx.setFillColor(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: inkRGB)!); ctx.addPath(artwork); ctx.fillPath()
    let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent(filename) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyDPIWidth: 2540, kCGImagePropertyDPIHeight: 2540] as CFDictionary)
    precondition(CGImageDestinationFinalize(dest))
}
try render(filename: "blocked-tab-upload.png", preview: false)
try render(filename: "blocked-tab-placement-preview.png", preview: true)
let info: [String: Any] = [
    "font": CTFontCopyFullName(font) as String,
    "postscript_name": CTFontCopyPostScriptName(font) as String,
    "font_source": "Installed macOS /System/Library/Fonts/SFCompact.ttf; font binary not distributed",
    "ink_srgb_hex": inkHex, "color_basis": "Visual Apple-style gray approximation, not an official Apple ink specification",
    "text": "blocked", "word_width_mm": 9, "left_inset_mm": 2, "bottom_inset_mm": 2,
    "nominal_canvas_mm": [27,18], "png_pixels": [width,height],
    "ink_bounds_pixels": [artwork.boundingBoxOfPath.minX, artwork.boundingBoxOfPath.minY, artwork.boundingBoxOfPath.width, artwork.boundingBoxOfPath.height],
    "caution": "Canvas represents placement intent; actual vendor top printable dimensions remain unverified. Request proof. Preview outline is not printable artwork."
]
let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("artwork-spec.json"))
print(String(data: data, encoding: .utf8)!)
