import AppKit

let W: CGFloat = 1600, H: CGFloat = 1000
let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()

// Canvas
NSGradient(colors: [
    NSColor(srgbRed: 0.05, green: 0.05, blue: 0.07, alpha: 1),
    NSColor(srgbRed: 0.09, green: 0.09, blue: 0.11, alpha: 1)
])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerX: CGFloat, top: CGFloat, tracking: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: tracking
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    let bounds = str.size()
    str.draw(at: NSPoint(x: centerX - bounds.width / 2, y: H - top - bounds.height))
}

func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

// Wordmark + tagline
text("dict8", size: 96, weight: .bold, color: .white, centerX: W / 2, top: 60, tracking: -2)
text("Type with your voice. In any app.", size: 26, weight: .regular,
     color: NSColor(white: 1, alpha: 0.55), centerX: W / 2, top: 170)

// Keyboard card
let cardX: CGFloat = 250, cardW: CGFloat = 1100
let cardY: CGFloat = H - 700, cardH: CGFloat = 392
rounded(NSRect(x: cardX, y: cardY, width: cardW, height: cardH), 44, NSColor(white: 0.11, alpha: 1))

let pad: CGFloat = 26
let gap: CGFloat = 8
let keyW = (cardW - pad * 2 - gap * 9) / 10
let keyH: CGFloat = 78
var rowY = cardY + cardH - pad - keyH

func key(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ label: String, tone: CGFloat, size: CGFloat = 30, color: NSColor = .white) {
    rounded(NSRect(x: x, y: y, width: w, height: h), 12, NSColor(white: tone, alpha: 1))
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: .regular),
        .foregroundColor: color
    ]
    let str = NSAttributedString(string: label, attributes: attrs)
    let b = str.size()
    str.draw(at: NSPoint(x: x + (w - b.width) / 2, y: y + (h - b.height) / 2))
}

let rows: [[String]] = [
    ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
    ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
    ["⇧", "Z", "X", "C", "V", "B", "N", "M", "⌫"]
]
for (index, row) in rows.enumerated() {
    let count = row.count
    let totalW = CGFloat(count) * keyW + CGFloat(count - 1) * gap
    var x = cardX + (cardW - totalW) / 2
    for label in row {
        let special = ["⇧", "⌫"].contains(label)
        key(x, rowY, keyW, keyH, label, tone: special ? 0.29 : 0.23)
        x += keyW + gap
    }
    rowY -= keyH + gap
}

// Bottom row
let bottomH: CGFloat = 82
var bx = cardX + pad
key(bx, rowY - 4, 112, bottomH, "123", tone: 0.29, size: 24)
bx += 112 + gap
key(bx, rowY - 4, 88, bottomH, "☺", tone: 0.29, size: 26)
bx += 88 + gap
rounded(NSRect(x: bx, y: rowY - 4, width: 96, height: bottomH), 12, NSColor(srgbRed: 1.0, green: 0.27, blue: 0.23, alpha: 1))
let micStr = NSAttributedString(string: "🎤", attributes: [.font: NSFont.systemFont(ofSize: 26)])
let micSize = micStr.size()
micStr.draw(at: NSPoint(x: bx + (96 - micSize.width) / 2, y: rowY - 4 + (bottomH - micSize.height) / 2))
bx += 96 + gap
let spaceW = cardW - pad * 2 - (112 + 88 + 150) - 96 - gap * 5
key(bx, rowY - 4, spaceW, bottomH, "space", tone: 0.23, size: 22, color: NSColor(white: 1, alpha: 0.8))
bx += spaceW + gap
key(bx, rowY - 4, 150, bottomH, "return", tone: 0.29, size: 22)

// Feature line
text("QWERTY · QWERTZ · Turkish", size: 22, weight: .medium,
     color: NSColor(white: 1, alpha: 0.5), centerX: W / 2, top: 760)
text("On-device dictation · Haptics · Light and dark", size: 20, weight: .regular,
     color: NSColor(white: 1, alpha: 0.38), centerX: W / 2, top: 800)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote", CommandLine.arguments[1])
