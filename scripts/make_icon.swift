#!/usr/bin/env swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Rend l'icône MaxiTerm (1024×1024) : fond sombre dégradé + prompt « ❯_ » vert.
let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("contexte") }

let s = CGFloat(size)

// Fond : dégradé vertical sombre.
let colors = [
    CGColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1),
    CGColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1),
] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// Couleur d'accent (vert terminal).
let green = CGColor(red: 0.137, green: 0.82, blue: 0.478, alpha: 1)

// Chevron « ❯ » épais.
ctx.setStrokeColor(green)
ctx.setLineWidth(64)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
let cx: CGFloat = 360
let midY: CGFloat = s / 2
let arm: CGFloat = 150
ctx.move(to: CGPoint(x: cx - arm * 0.7, y: midY + arm))
ctx.addLine(to: CGPoint(x: cx + arm * 0.7, y: midY))
ctx.addLine(to: CGPoint(x: cx - arm * 0.7, y: midY - arm))
ctx.strokePath()

// Curseur « _ » (barre arrondie).
ctx.setFillColor(green)
let cursor = CGRect(x: 520, y: midY - arm - 8, width: 230, height: 60)
let cursorPath = CGPath(roundedRect: cursor, cornerWidth: 24, cornerHeight: 24, transform: nil)
ctx.addPath(cursorPath)
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("image") }
let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"
let url = URL(fileURLWithPath: out)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("destination")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("écrit : \(out)")
