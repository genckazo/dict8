import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background gradient.
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.24, green: 0.47, blue: 1.0, alpha: 1),
    NSColor(srgbRed: 0.04, green: 0.16, blue: 0.47, alpha: 1)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// Keyboard body.
let body = NSBezierPath(roundedRect: NSRect(x: 132, y: 262, width: 760, height: 500), xRadius: 96, yRadius: 96)
NSColor(white: 1, alpha: 0.96).setFill()
body.fill()

// Keys.
let keyColor = NSColor(srgbRed: 0.13, green: 0.31, blue: 0.80, alpha: 1)
func key(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: 18, yRadius: 18)
    keyColor.setFill()
    path.fill()
}

let left: CGFloat = 196
let keyW: CGFloat = 136
let gap: CGFloat = 24
for row in 0..<3 {
    let y = 606 - CGFloat(row) * 112
    for column in 0..<4 {
        key(left + CGFloat(column) * (keyW + gap), y, keyW, 84)
    }
}
// Wide space key row.
key(left, 342, 4 * keyW + 3 * gap, 84)

// Microphone badge.
let badge = NSBezierPath(ovalIn: NSRect(x: 668, y: 590, width: 250, height: 250))
NSColor(srgbRed: 1.0, green: 0.30, blue: 0.24, alpha: 1).setFill()
badge.fill()
NSColor.white.setStroke()

// Mic capsule.
let capsule = NSBezierPath(roundedRect: NSRect(x: 762, y: 700, width: 62, height: 112), xRadius: 31, yRadius: 31)
NSColor.white.setFill()
capsule.fill()

// Mic cradle and stem.
let cradle = NSBezierPath()
cradle.appendArc(withCenter: NSPoint(x: 793, y: 748), radius: 56, startAngle: 200, endAngle: -20, clockwise: true)
cradle.lineWidth = 18
NSColor.white.setStroke()
cradle.stroke()

let stem = NSBezierPath()
stem.move(to: NSPoint(x: 793, y: 700))
stem.line(to: NSPoint(x: 793, y: 660))
stem.lineWidth = 18
stem.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not render icon")
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: out)
print("wrote \(out.path)")
