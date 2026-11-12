// Draws Tilt's app icon: a laptop screen tipped on its side with a curved arrow.
import AppKit
let out = CommandLine.arguments[1]
func draw(_ s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let u = s / 1024
    // Warm paper background
    NSColor(red: 0.96, green: 0.91, blue: 0.82, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 100*u, y: 100*u, width: 824*u, height: 824*u), xRadius: 185*u, yRadius: 185*u).fill()
    // Tipped screen
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: 512*u, y: 500*u); ctx.rotate(by: -.pi/2 * 0.82)
    NSColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: -250*u, y: -160*u, width: 500*u, height: 320*u), xRadius: 28*u, yRadius: 28*u).fill()
    NSColor(red: 0.30, green: 0.62, blue: 0.86, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: -222*u, y: -132*u, width: 444*u, height: 264*u), xRadius: 12*u, yRadius: 12*u).fill()
    NSColor(red: 0.98, green: 0.80, blue: 0.30, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 90*u, y: 30*u, width: 70*u, height: 70*u)).fill()
    NSColor(red: 0.20, green: 0.48, blue: 0.36, alpha: 1).setFill()
    let hill = NSBezierPath(); hill.move(to: NSPoint(x: -222*u, y: -132*u)); hill.line(to: NSPoint(x: -222*u, y: -40*u))
    hill.curve(to: NSPoint(x: 222*u, y: -60*u), controlPoint1: NSPoint(x: -80*u, y: 40*u), controlPoint2: NSPoint(x: 80*u, y: -120*u))
    hill.line(to: NSPoint(x: 222*u, y: -132*u)); hill.close(); hill.fill()
    ctx.restoreGState()
    // Curved arrow
    NSColor(red: 0.85, green: 0.33, blue: 0.20, alpha: 1).setStroke()
    let arc = NSBezierPath(); arc.lineWidth = 46*u; arc.lineCapStyle = .round
    arc.appendArc(withCenter: NSPoint(x: 512*u, y: 500*u), radius: 330*u, startAngle: 120, endAngle: 40, clockwise: true)
    arc.stroke()
    NSColor(red: 0.85, green: 0.33, blue: 0.20, alpha: 1).setFill()
    let tip = NSPoint(x: 512*u + 330*u*cos(40 * .pi/180), y: 500*u + 330*u*sin(40 * .pi/180))
    let head = NSBezierPath()
    head.move(to: NSPoint(x: tip.x - 70*u, y: tip.y + 40*u)); head.line(to: NSPoint(x: tip.x + 70*u, y: tip.y + 50*u))
    head.line(to: NSPoint(x: tip.x + 10*u, y: tip.y - 85*u)); head.close(); head.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let fm = FileManager.default
try? fm.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, size) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    try! draw(CGFloat(size)).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
