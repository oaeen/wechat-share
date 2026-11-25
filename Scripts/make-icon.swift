import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("usage: make-icon.swift <iconset-directory> <lucide-svg>\n".utf8)
    )
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconSource = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
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

for (name, pixels) in entries {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("cannot create \(pixels)px bitmap")
    }
    representation.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    guard let graphics = NSGraphicsContext(bitmapImageRep: representation) else {
        fatalError("cannot create graphics context")
    }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    let tile = CGRect(x: 92, y: 92, width: 840, height: 840)
    let rounded = CGPath(
        roundedRect: tile,
        cornerWidth: 190,
        cornerHeight: 190,
        transform: nil
    )
    context.saveGState()
    context.addPath(rounded)
    context.clip()
    context.setFillColor(NSColor(calibratedRed: 0.03, green: 0.76, blue: 0.38, alpha: 1).cgColor)
    context.fill(tile)
    context.restoreGState()

    var svg = try String(contentsOf: iconSource, encoding: .utf8)
    svg = svg.replacingOccurrences(of: "currentColor", with: "#FFFFFF")
    svg = svg.replacingOccurrences(of: "stroke-width=\"2\"", with: "stroke-width=\"2.4\"")
    guard let icon = NSImage(data: Data(svg.utf8)) else {
        fatalError("cannot load icon svg: \(iconSource.path)")
    }
    icon.draw(
        in: NSRect(x: 252, y: 252, width: 520, height: 520),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = representation.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(name)")
    }
    try png.write(to: output.appendingPathComponent(name))
}
