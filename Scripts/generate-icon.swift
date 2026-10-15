import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
}

func polygon(_ points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    path.lineJoinStyle = .round
    return path
}

@MainActor
func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.imageInterpolation = .high
    context.shouldAntialias = true

    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                            xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0.25, 0.53, 0.43).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.76, 0.92, 0.80), ending: color(0.29, 0.61, 0.49))!
        .draw(in: tile, angle: -65)
    NSColor.white.withAlphaComponent(0.36).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    let left = polygon([NSPoint(x: 266, y: 570), NSPoint(x: 500, y: 459),
                        NSPoint(x: 500, y: 262), NSPoint(x: 266, y: 373)])
    let right = polygon([NSPoint(x: 500, y: 459), NSPoint(x: 744, y: 570),
                         NSPoint(x: 744, y: 373), NSPoint(x: 500, y: 262)])
    NSGraphicsContext.saveGraphicsState()
    shadow.shadowColor = color(0.10, 0.29, 0.21).withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.set()
    color(0.93, 0.93, 0.81).setFill()
    left.fill()
    right.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.99, 0.98, 0.89), ending: color(0.89, 0.91, 0.77))!
        .draw(in: left, angle: -90)
    NSGradient(starting: color(0.88, 0.92, 0.78), ending: color(0.73, 0.83, 0.64))!
        .draw(in: right, angle: -90)

    let lid = polygon([NSPoint(x: 252, y: 600), NSPoint(x: 500, y: 716),
                       NSPoint(x: 758, y: 600), NSPoint(x: 500, y: 478)])
    let lipLeft = polygon([NSPoint(x: 252, y: 600), NSPoint(x: 500, y: 478),
                           NSPoint(x: 500, y: 449), NSPoint(x: 252, y: 568)])
    let lipRight = polygon([NSPoint(x: 500, y: 478), NSPoint(x: 758, y: 600),
                            NSPoint(x: 758, y: 568), NSPoint(x: 500, y: 449)])
    color(0.98, 0.96, 0.85).setFill()
    lipLeft.fill()
    color(0.83, 0.89, 0.73).setFill()
    lipRight.fill()
    NSGradient(starting: color(1, 1, 0.95), ending: color(0.94, 0.96, 0.85))!
        .draw(in: lid, angle: -90)
    NSColor.white.withAlphaComponent(0.62).setStroke()
    lid.lineWidth = 3
    lid.stroke()

    let slot = NSBezierPath()
    slot.move(to: NSPoint(x: 345, y: 444))
    slot.line(to: NSPoint(x: 422, y: 407))
    slot.lineWidth = 15
    slot.lineCapStyle = .round
    color(0.39, 0.55, 0.39).setStroke()
    slot.stroke()

    let cursor = polygon([NSPoint(x: 660, y: 438), NSPoint(x: 661, y: 229),
                          NSPoint(x: 716, y: 276), NSPoint(x: 752, y: 199),
                          NSPoint(x: 796, y: 220), NSPoint(x: 758, y: 295),
                          NSPoint(x: 827, y: 305)])
    NSGraphicsContext.saveGraphicsState()
    shadow.shadowColor = color(0.08, 0.27, 0.20).withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 12
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    shadow.set()
    color(0.99, 1, 0.96).setFill()
    cursor.fill()
    NSGraphicsContext.restoreGraphicsState()
    color(0.13, 0.34, 0.27).setStroke()
    cursor.lineWidth = 12
    cursor.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let bitmap = drawIcon(pixels: size * scale)
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent(filename))
    }
}
print("Generated icon images: \(output.path)")
