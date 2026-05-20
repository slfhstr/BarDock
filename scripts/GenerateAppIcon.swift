import AppKit
import Foundation

struct IconEntry {
    let filename: String
    let pixels: Int
}

let entries = [
    IconEntry(filename: "icon_16x16.png", pixels: 16),
    IconEntry(filename: "icon_16x16@2x.png", pixels: 32),
    IconEntry(filename: "icon_32x32.png", pixels: 32),
    IconEntry(filename: "icon_32x32@2x.png", pixels: 64),
    IconEntry(filename: "icon_128x128.png", pixels: 128),
    IconEntry(filename: "icon_128x128@2x.png", pixels: 256),
    IconEntry(filename: "icon_256x256.png", pixels: 256),
    IconEntry(filename: "icon_256x256@2x.png", pixels: 512),
    IconEntry(filename: "icon_512x512.png", pixels: 512),
    IconEntry(filename: "icon_512x512@2x.png", pixels: 1024)
]

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("Usage: GenerateAppIcon <iconset-path> <preview-png-path> <icns-path>\n".utf8))
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1])
let previewURL = URL(fileURLWithPath: CommandLine.arguments[2])
let icnsURL = URL(fileURLWithPath: CommandLine.arguments[3])
let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

var icnsSources: [(String, Data)] = []

for entry in entries {
    let image = drawIcon(size: entry.pixels)
    let outputURL = iconsetURL.appendingPathComponent(entry.filename)
    try savePNG(image: image, to: outputURL)

    if let type = icnsType(forPixels: entry.pixels, filename: entry.filename),
       let data = image.representation(using: .png, properties: [:]) {
        icnsSources.append((type, data))
    }

    if entry.pixels == 512 && entry.filename == "icon_512x512.png" {
        try savePNG(image: image, to: previewURL)
    }
}

try saveICNS(entries: icnsSources, to: icnsURL)

func drawIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let canvas = CGFloat(size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

    let background = NSBezierPath(
        roundedRect: NSRect(x: canvas * 0.08, y: canvas * 0.08, width: canvas * 0.84, height: canvas * 0.84),
        xRadius: canvas * 0.20,
        yRadius: canvas * 0.20
    )
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.15, alpha: 1.0),
        NSColor(calibratedRed: 0.72, green: 0.28, blue: 0.78, alpha: 1.0)
    ])!
    gradient.draw(in: background, angle: 35)

    NSColor(calibratedWhite: 1.0, alpha: 0.20).setStroke()
    background.lineWidth = max(1, canvas * 0.012)
    background.stroke()

    let shelf = NSBezierPath(
        roundedRect: NSRect(x: canvas * 0.15, y: canvas * 0.42, width: canvas * 0.70, height: canvas * 0.20),
        xRadius: canvas * 0.10,
        yRadius: canvas * 0.10
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.82).setFill()
    shelf.fill()

    drawGear(in: NSRect(x: canvas * 0.21, y: canvas * 0.455, width: canvas * 0.13, height: canvas * 0.13), canvas: canvas)

    let tileColors = [
        NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.95, alpha: 1.0),
        NSColor(calibratedRed: 0.16, green: 0.70, blue: 0.44, alpha: 1.0),
        NSColor(calibratedRed: 0.98, green: 0.36, blue: 0.24, alpha: 1.0),
        NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.22, alpha: 1.0)
    ]

    for index in 0..<4 {
        let x = canvas * (0.40 + CGFloat(index) * 0.085)
        let tile = NSBezierPath(
            roundedRect: NSRect(x: x, y: canvas * 0.472, width: canvas * 0.055, height: canvas * 0.055),
            xRadius: canvas * 0.014,
            yRadius: canvas * 0.014
        )
        tileColors[index].setFill()
        tile.fill()
    }

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: canvas * 0.72, y: canvas * 0.47))
    arrow.line(to: NSPoint(x: canvas * 0.78, y: canvas * 0.52))
    arrow.line(to: NSPoint(x: canvas * 0.72, y: canvas * 0.57))
    NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.18, alpha: 1.0).setStroke()
    arrow.lineWidth = max(2, canvas * 0.026)
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawGear(in rect: NSRect, canvas: CGFloat) {
    let center = NSPoint(x: rect.midX, y: rect.midY)
    let outerRadius = rect.width / 2
    let innerRadius = outerRadius * 0.58
    let toothWidth = max(1, canvas * 0.020)

    NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.18, alpha: 1.0).setFill()
    for index in 0..<8 {
        let angle = CGFloat(index) * (.pi / 4)
        let toothCenter = NSPoint(
            x: center.x + cos(angle) * outerRadius * 0.90,
            y: center.y + sin(angle) * outerRadius * 0.90
        )
        let tooth = NSBezierPath(
            roundedRect: NSRect(
                x: toothCenter.x - toothWidth / 2,
                y: toothCenter.y - toothWidth / 2,
                width: toothWidth,
                height: toothWidth
            ),
            xRadius: toothWidth / 3,
            yRadius: toothWidth / 3
        )
        tooth.fill()
    }
    NSBezierPath(ovalIn: rect.insetBy(dx: outerRadius * 0.12, dy: outerRadius * 0.12)).fill()

    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(ovalIn: rect.insetBy(dx: innerRadius * 0.52, dy: innerRadius * 0.52)).fill()
}

func savePNG(image: NSBitmapImageRep, to url: URL) throws {
    guard let data = image.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "BarDockIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG data"])
    }
    try data.write(to: url)
}

func icnsType(forPixels pixels: Int, filename: String) -> String? {
    switch (pixels, filename.contains("@2x")) {
    case (16, false): return "icp4"
    case (32, true): return "ic11"
    case (32, false): return "icp5"
    case (64, true): return "ic12"
    case (64, false): return "icp6"
    case (128, false): return "ic07"
    case (256, true): return "ic13"
    case (256, false): return "ic08"
    case (512, true): return "ic14"
    case (512, false): return "ic09"
    case (1024, true): return "ic10"
    default: return nil
    }
}

func saveICNS(entries: [(String, Data)], to url: URL) throws {
    var data = Data()
    data.append(contentsOf: [0x69, 0x63, 0x6E, 0x73])

    let tocLength = 8 + entries.count * 8
    let totalLength = 8 + tocLength + entries.reduce(0) { $0 + 8 + $1.1.count }
    appendUInt32(UInt32(totalLength), to: &data)

    data.append(Data("TOC ".utf8))
    appendUInt32(UInt32(tocLength), to: &data)
    for entry in entries {
        data.append(Data(entry.0.utf8))
        appendUInt32(UInt32(entry.1.count + 8), to: &data)
    }

    for entry in entries {
        data.append(Data(entry.0.utf8))
        appendUInt32(UInt32(entry.1.count + 8), to: &data)
        data.append(entry.1)
    }

    try data.write(to: url)
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}
