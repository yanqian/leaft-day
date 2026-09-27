import AppKit
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let seed = Int(CommandLine.arguments[2])!
let samples: [(String, Int, Int, String, Int)] = [
    ("landscape", 1200, 800, "2025:09:27 10:00:00", 0),
    ("landscape-near", 1200, 800, "2025:09:27 10:00:02", 1),
    ("portrait-smile", 800, 1200, "2025:09:27 10:10:00", 2),
    ("portrait-frown", 800, 1200, "2025:09:27 10:10:01", 3),
    ("square", 900, 900, "2025:09:27 18:00:00", 4),
    ("leap-day", 1000, 700, "2024:02:29 09:00:00", 5),
    ("later-day", 700, 1000, "2026:01:02 12:00:00", 6)
]
for (name, width, height, date, variant) in samples {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let hue = CGFloat((seed % 100) + 20) / 150
    context.setFillColor(CGColor(red: 0.12, green: hue, blue: 0.7, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if variant == 2 || variant == 3 {
        context.setFillColor(CGColor(red: 1, green: 0.8, blue: 0.45, alpha: 1))
        context.fillEllipse(in: CGRect(x: 100, y: 250, width: 600, height: 700))
        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        for x in [260, 500] { context.fillEllipse(in: CGRect(x: x, y: 680, width: 45, height: 65)) }
        context.setStrokeColor(CGColor(gray: 0.1, alpha: 1)); context.setLineWidth(20)
        context.move(to: CGPoint(x: 250, y: 490))
        context.addQuadCurve(to: CGPoint(x: 550, y: 490), control: CGPoint(x: 400, y: variant == 2 ? 270 : 660))
        context.strokePath()
    } else {
        context.setFillColor(CGColor(red: 0.05, green: 0.3, blue: 0.15, alpha: 1))
        context.move(to: CGPoint(x: 0, y: 0)); context.addLine(to: CGPoint(x: 0, y: height / 3))
        context.addLine(to: CGPoint(x: width / 2, y: height * 2 / 3)); context.addLine(to: CGPoint(x: width, y: 0)); context.fillPath()
        context.setFillColor(CGColor(red: 1, green: 0.8, blue: 0.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: width * 3 / 4 + (variant == 1 ? 5 : 0), y: height * 3 / 4, width: 80, height: 80))
    }
    let image = context.makeImage()!
    let url = output.appendingPathComponent(name + ".jpg")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { fatalError("Cannot create image") }
    let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.94,
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: date, kCGImagePropertyExifDateTimeDigitized: date],
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFDateTime: date], kCGImagePropertyOrientation: 1]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write image") }
}
