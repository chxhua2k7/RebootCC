// 「設定 → 控制中心」清單裡 RebootCC 的圖示(CCSupport 讀模組 bundle 裡的 SettingsIcon):
// 紅底白色 arrow.clockwise,iOS 圓角,輸出 module/Resources/ 的 58/87 和 logo/ 的 1024。
// 用法:swift logo/make_icon.swift .
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let tileColor = NSColor(srgbRed: 1.0, green: 0x3B / 255.0, blue: 0x30 / 255.0, alpha: 1) // systemRed

func render(_ size: Int, to url: URL) {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    NSBezierPath(roundedRect: rect, xRadius: s * 0.2237, yRadius: s * 0.2237).addClip()
    tileColor.setFill()
    rect.fill()

    let configuration = NSImage.SymbolConfiguration(pointSize: s * 0.55, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    let glyph = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)!
        .withSymbolConfiguration(configuration)!
    let g = glyph.size
    glyph.draw(in: NSRect(x: (s - g.width) / 2, y: (s - g.height) / 2, width: g.width, height: g.height))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

render(58, to: root.appendingPathComponent("module/Resources/SettingsIcon@2x.png"))
render(87, to: root.appendingPathComponent("module/Resources/SettingsIcon@3x.png"))
render(1024, to: root.appendingPathComponent("logo/RebootCC-1024.png"))
print("done")
