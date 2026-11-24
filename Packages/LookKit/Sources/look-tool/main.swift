// look-tool — developer helper for looks (never part of the app).
//
//   look-tool render-samples              write a placeholder sample image for every bundled look
//                                         (into Sources/LookKit/Resources/Looks; license: placeholder-generated)
//   look-tool compare <image> [OUT_DIR]   render a photo with every look (strength 1) for side-by-side review
//   look-tool check-licenses [--release]  every image in the looks folder has a license record (spec 03 FR-009);
//                                         --release also refuses placeholder images. Exit 1 on any problem.
//
// Run from Packages/LookKit: `swift run look-tool …`

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import LookKit
import UniformTypeIdentifiers

let context = CIContext()
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8)); exit(2)
}

func writeJPEG(_ image: CIImage, to url: URL) {
    do { try context.writeJPEGRepresentation(of: image, to: url, colorSpace: sRGB, options: [:]) }
    catch { fail("cannot write \(url.path): \(error)") }
}

/// Synthetic cafe scene used for placeholder samples until licensed photos arrive (spec 03 karar 1).
func placeholderScene(width: Int = 480, height: Int = 600) -> CIImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let table = [CGColor(red: 0.80, green: 0.66, blue: 0.50, alpha: 1), CGColor(red: 0.45, green: 0.31, blue: 0.21, alpha: 1)] as CFArray
    ctx.drawLinearGradient(CGGradient(colorsSpace: sRGB, colors: table, locations: [0, 1])!,
                           start: CGPoint(x: 0, y: height), end: .zero, options: [])
    // Saucer, cup, coffee, latte art.
    let cx = CGFloat(width) / 2, cy = CGFloat(height) * 0.45
    ctx.setFillColor(CGColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - 170, y: cy - 170, width: 340, height: 340))
    ctx.setFillColor(CGColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - 120, y: cy - 120, width: 240, height: 240))
    ctx.setFillColor(CGColor(red: 0.42, green: 0.25, blue: 0.13, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - 100, y: cy - 100, width: 200, height: 200))
    ctx.setFillColor(CGColor(red: 0.88, green: 0.76, blue: 0.60, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - 40, y: cy - 50, width: 80, height: 95))
    // A croissant-ish shape and a green leaf for color.
    ctx.setFillColor(CGColor(red: 0.85, green: 0.58, blue: 0.25, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: 40, y: CGFloat(height) - 170, width: 170, height: 90))
    ctx.setFillColor(CGColor(red: 0.30, green: 0.55, blue: 0.28, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: CGFloat(width) - 150, y: 60, width: 110, height: 60))
    return CIImage(cgImage: ctx.makeImage()!)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { fail("usage: look-tool render-samples | compare <image> [OUT_DIR]") }
let renderer = LookRenderer()

switch command {
case "check-licenses":
    let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/LookKit/Resources/Looks", isDirectory: true)
    let problems = LicenseCheck.problems(in: dir, release: args.contains("--release"))
    for p in problems { FileHandle.standardError.write(Data("license: \(p)\n".utf8)) }
    if !problems.isEmpty { exit(1) }
    print("licenses ok")
case "render-samples":
    let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/LookKit/Resources/Looks", isDirectory: true)
    let catalog = LookCatalog(directory: dir)
    guard !catalog.looks.isEmpty else { fail("no looks in \(dir.path); run from Packages/LookKit") }
    let scene = placeholderScene()
    for look in catalog.looks {
        guard let name = look.sample?.image else { print("skip \(look.id): no sample entry"); continue }
        writeJPEG(renderer.render(scene, recipe: look, strength: 1), to: dir.appendingPathComponent(name))
        print("wrote \(name)")
    }

case "compare":
    guard args.count >= 2 else { fail("usage: look-tool compare <image> [OUT_DIR]") }
    let input = URL(fileURLWithPath: args[1])
    guard let image = CIImage(contentsOf: input, options: [.applyOrientationProperty: true]) else { fail("cannot read \(input.path)") }
    let out = URL(fileURLWithPath: args.count > 2 ? args[2] : FileManager.default.currentDirectoryPath, isDirectory: true)
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let stem = input.deletingPathExtension().lastPathComponent
    for look in try LookCatalog.bundled().strip {
        let url = out.appendingPathComponent("\(stem)-\(look.id).jpg")
        writeJPEG(renderer.render(image, recipe: look, strength: 1), to: url)
        print("wrote \(url.path)")
    }

default:
    fail("unknown command \(command)")
}
