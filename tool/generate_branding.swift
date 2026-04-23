import AppKit
import Foundation

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)

func ensureDirectory(_ url: URL) {
  try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func savePNG(_ image: NSImage, to url: URL) throws {
  guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
  else {
    throw NSError(domain: "branding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
  }
  try data.write(to: url)
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
  color.setFill()
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawText(
  _ text: String,
  in rect: NSRect,
  font: NSFont,
  color: NSColor,
  alignment: NSTextAlignment = .center
) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = alignment
  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: color,
    .paragraphStyle: paragraph,
  ]
  let attributed = NSAttributedString(string: text, attributes: attributes)
  attributed.draw(in: rect)
}

func makeIcon(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()

  let canvas = NSRect(x: 0, y: 0, width: size, height: size)
  NSColor.clear.setFill()
  canvas.fill()

  let inset = size * 0.08
  let cardRect = canvas.insetBy(dx: inset, dy: inset)
  drawRoundedRect(cardRect, radius: size * 0.22, color: NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.24, alpha: 1.0))

  let accentRect = NSRect(
    x: cardRect.minX,
    y: cardRect.minY,
    width: cardRect.width,
    height: cardRect.height * 0.33
  )
  let accentPath = NSBezierPath(roundedRect: accentRect, xRadius: size * 0.18, yRadius: size * 0.18)
  NSColor(calibratedRed: 0.73, green: 0.57, blue: 0.19, alpha: 1.0).setFill()
  accentPath.fill()

  let receiptRect = NSRect(
    x: size * 0.28,
    y: size * 0.24,
    width: size * 0.44,
    height: size * 0.52
  )
  drawRoundedRect(receiptRect, radius: size * 0.05, color: .white)

  let topStripe = NSRect(
    x: receiptRect.minX,
    y: receiptRect.maxY - size * 0.1,
    width: receiptRect.width,
    height: size * 0.1
  )
  NSColor(calibratedRed: 0.73, green: 0.57, blue: 0.19, alpha: 1.0).setFill()
  topStripe.fill()

  let rupeeFont = NSFont.systemFont(ofSize: size * 0.17, weight: .bold)
  drawText(
    "₹",
    in: NSRect(
      x: receiptRect.minX,
      y: receiptRect.midY - size * 0.12,
      width: receiptRect.width,
      height: size * 0.2
    ),
    font: rupeeFont,
    color: NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.24, alpha: 1.0)
  )

  let barcodeY = receiptRect.minY + size * 0.08
  let barWidth = size * 0.018
  let gaps = size * 0.012
  let heights: [CGFloat] = [0.11, 0.16, 0.13, 0.18, 0.1]
  var currentX = receiptRect.midX - ((CGFloat(heights.count) * barWidth) + (CGFloat(heights.count - 1) * gaps)) / 2
  for h in heights {
    let barRect = NSRect(x: currentX, y: barcodeY, width: barWidth, height: size * h)
    NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.24, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    currentX += barWidth + gaps
  }

  image.unlockFocus()
  return image
}

func makeSplash(width: CGFloat, height: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: width, height: height))
  image.lockFocus()

  let canvas = NSRect(x: 0, y: 0, width: width, height: height)
  NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.95, alpha: 1.0).setFill()
  canvas.fill()

  let topGlow = NSBezierPath(ovalIn: NSRect(
    x: width * 0.12,
    y: height * 0.58,
    width: width * 0.76,
    height: height * 0.36
  ))
  NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.92, alpha: 1.0).setFill()
  topGlow.fill()

  let iconSize = min(width, height) * 0.27
  let icon = makeIcon(size: iconSize)
  let iconRect = NSRect(
    x: (width - iconSize) / 2,
    y: height * 0.5,
    width: iconSize,
    height: iconSize
  )
  icon.draw(in: iconRect)

  drawText(
    "Retail Billing App",
    in: NSRect(x: width * 0.15, y: height * 0.33, width: width * 0.7, height: 50),
    font: NSFont.systemFont(ofSize: min(width, height) * 0.05, weight: .bold),
    color: NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.24, alpha: 1.0)
  )
  drawText(
    "Smart billing for modern retail dealers",
    in: NSRect(x: width * 0.12, y: height * 0.27, width: width * 0.76, height: 34),
    font: NSFont.systemFont(ofSize: min(width, height) * 0.024, weight: .medium),
    color: NSColor(calibratedRed: 0.35, green: 0.43, blue: 0.42, alpha: 1.0)
  )

  image.unlockFocus()
  return image
}

let brandingDir = root.appendingPathComponent("assets/branding")
let androidRes = root.appendingPathComponent("android/app/src/main/res")
let iosIconDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let iosLaunchDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/LaunchImage.imageset")
let androidDrawableNoDpi = androidRes.appendingPathComponent("drawable-nodpi")

ensureDirectory(brandingDir)
ensureDirectory(androidDrawableNoDpi)

let iconMaster = makeIcon(size: 1024)
let splashMaster = makeSplash(width: 1668, height: 2388)

try savePNG(iconMaster, to: brandingDir.appendingPathComponent("retail_billing_app_icon.png"))
try savePNG(splashMaster, to: brandingDir.appendingPathComponent("retail_billing_app_splash.png"))

let androidIconSizes: [(String, CGFloat)] = [
  ("mipmap-mdpi/ic_launcher.png", 48),
  ("mipmap-hdpi/ic_launcher.png", 72),
  ("mipmap-xhdpi/ic_launcher.png", 96),
  ("mipmap-xxhdpi/ic_launcher.png", 144),
  ("mipmap-xxxhdpi/ic_launcher.png", 192),
]

for (path, size) in androidIconSizes {
  let image = makeIcon(size: size)
  try savePNG(image, to: androidRes.appendingPathComponent(path))
}

try savePNG(makeSplash(width: 720, height: 1280), to: androidDrawableNoDpi.appendingPathComponent("launch_logo.png"))

let iosIconSizes: [(String, CGFloat)] = [
  ("Icon-App-20x20@1x.png", 20),
  ("Icon-App-20x20@2x.png", 40),
  ("Icon-App-20x20@3x.png", 60),
  ("Icon-App-29x29@1x.png", 29),
  ("Icon-App-29x29@2x.png", 58),
  ("Icon-App-29x29@3x.png", 87),
  ("Icon-App-40x40@1x.png", 40),
  ("Icon-App-40x40@2x.png", 80),
  ("Icon-App-40x40@3x.png", 120),
  ("Icon-App-60x60@2x.png", 120),
  ("Icon-App-60x60@3x.png", 180),
  ("Icon-App-76x76@1x.png", 76),
  ("Icon-App-76x76@2x.png", 152),
  ("Icon-App-83.5x83.5@2x.png", 167),
  ("Icon-App-1024x1024@1x.png", 1024),
]

for (filename, size) in iosIconSizes {
  try savePNG(makeIcon(size: size), to: iosIconDir.appendingPathComponent(filename))
}

let iosLaunchSizes: [(String, CGFloat, CGFloat)] = [
  ("LaunchImage.png", 276, 368),
  ("LaunchImage@2x.png", 552, 736),
  ("LaunchImage@3x.png", 828, 1104),
]

for (filename, width, height) in iosLaunchSizes {
  try savePNG(makeSplash(width: width, height: height), to: iosLaunchDir.appendingPathComponent(filename))
}

print("Branding assets generated.")
