import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <iconset-directory>\n".utf8))
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
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
    let colors = [
        NSColor(calibratedRed: 0.10, green: 0.82, blue: 0.45, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.02, green: 0.58, blue: 0.29, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: 932),
        end: CGPoint(x: 512, y: 92),
        options: []
    )
    context.restoreGState()

    context.setFillColor(NSColor.white.withAlphaComponent(0.46).cgColor)
    context.addPath(CGPath(
        roundedRect: CGRect(x: 250, y: 500, width: 430, height: 300),
        cornerWidth: 125,
        cornerHeight: 125,
        transform: nil
    ))
    context.fillPath()
    context.beginPath()
    context.move(to: CGPoint(x: 318, y: 515))
    context.addLine(to: CGPoint(x: 448, y: 515))
    context.addLine(to: CGPoint(x: 286, y: 410))
    context.closePath()
    context.fillPath()

    context.setFillColor(NSColor.white.cgColor)
    context.addPath(CGPath(
        roundedRect: CGRect(x: 354, y: 292, width: 462, height: 346),
        cornerWidth: 142,
        cornerHeight: 142,
        transform: nil
    ))
    context.fillPath()
    context.beginPath()
    context.move(to: CGPoint(x: 432, y: 306))
    context.addLine(to: CGPoint(x: 562, y: 306))
    context.addLine(to: CGPoint(x: 392, y: 200))
    context.closePath()
    context.fillPath()

    context.setFillColor(NSColor(calibratedRed: 0.02, green: 0.58, blue: 0.29, alpha: 1).cgColor)
    let lines = [
        CGRect(x: 450, y: 522, width: 270, height: 38),
        CGRect(x: 450, y: 448, width: 210, height: 38),
        CGRect(x: 450, y: 374, width: 238, height: 38),
    ]
    for line in lines {
        context.addPath(CGPath(
            roundedRect: line,
            cornerWidth: 19,
            cornerHeight: 19,
            transform: nil
        ))
        context.fillPath()
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = representation.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode \(name)")
    }
    try png.write(to: output.appendingPathComponent(name))
}
