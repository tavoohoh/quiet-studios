// Renders an SVG to a PNG with AppKit (no dependencies). Used by render-artwork.py.
// Usage: swift render-svg.swift <in.svg> <out.png> <width> <height> <opaque|alpha>
// "opaque" writes RGB without an alpha channel (required for the App Store icon).
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 6,
      let width = Int(arguments[3]), let height = Int(arguments[4]),
      let image = NSImage(contentsOf: URL(fileURLWithPath: arguments[1]))
else {
    FileHandle.standardError.write(Data("usage: render-svg.swift in.svg out.png width height opaque|alpha\n".utf8))
    exit(1)
}
let opaque = arguments[5] == "opaque"
// "opaque" skips the alpha channel; the background comes from the SVG itself.
let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue
)!
context.interpolationQuality = .high
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()
let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arguments[2]))
