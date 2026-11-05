// Renders an SVG into square PNGs with a transparent background.
// Usage: swift scripts/render-icon.swift <input.svg> <output-dir> <name>:<pixels> ...
// Run by scripts/make-icon.sh. Needs only the Xcode command line tools (AppKit draws the SVG).
import AppKit
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count >= 3 else {
  FileHandle.standardError.write(Data("usage: render-icon.swift <input.svg> <output-dir> <name>:<pixels> ...\n".utf8))
  exit(64)
}
let input = URL(fileURLWithPath: arguments[arguments.startIndex])
let outputDirectory = URL(fileURLWithPath: arguments[arguments.startIndex + 1], isDirectory: true)

guard let image = NSImage(contentsOf: input) else {
  FileHandle.standardError.write(Data("cannot read \(input.path)\n".utf8))
  exit(1)
}

for spec in arguments.dropFirst(2) {
  let parts = spec.split(separator: ":")
  guard parts.count == 2, let pixels = Int(parts[1]), pixels > 0 else {
    FileHandle.standardError.write(Data("bad size spec \(spec)\n".utf8))
    exit(64)
  }
  // Draw the vector image straight at the target pixel size (no resampling of a large bitmap).
  guard
    let context = CGContext(
      data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { exit(1) }
  context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
  image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
  NSGraphicsContext.restoreGraphicsState()

  let url = outputDirectory.appendingPathComponent(String(parts[0]))
  guard let cgImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { exit(1) }
  CGImageDestinationAddImage(destination, cgImage, nil)
  guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("cannot write \(url.path)\n".utf8))
    exit(1)
  }
}
