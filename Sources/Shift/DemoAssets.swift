import AppKit
import SwiftUI

func exportDemoAssets(to directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    func write(_ image: CGImage, _ name: String) throws {
        try Converter.encode(image, type: .png, quality: 1).write(to: directory.appendingPathComponent(name))
    }
    let sample = NSImage(size: NSSize(width: 600, height: 800), flipped: true) { rect in
        NSColor.white.setFill(); rect.fill()
        func text(_ value: String, _ x: Double, _ y: Double, _ size: Double, _ weight: NSFont.Weight = .regular, _ color: NSColor = .black) {
            (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        }
        text("FIELD NOTES / 001", 46, 43, 13, .semibold)
        text("Less clicking.", 43, 100, 49, .bold)
        text("More making.", 43, 159, 49, .bold)
        text("A smaller way to work.", 46, 239, 18, .regular, .darkGray)
        NSColor(calibratedRed: 0.97, green: 0.47, blue: 0.28, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 46, y: 302, width: 508, height: 308), xRadius: 12, yRadius: 12).fill()
        NSColor(calibratedRed: 0.98, green: 0.84, blue: 0.52, alpha: 1).setFill()
        for i in 0..<5 {
            NSBezierPath(ovalIn: NSRect(x: 77 + i * 75, y: 337 + i * 14, width: 190, height: 190)).fill()
        }
        text("01  Start with what you have.", 46, 647, 18, .medium)
        text("02  Keep the good parts.", 46, 684, 18, .medium)
        text("03  Get back to your day.", 46, 721, 18, .medium)
        return true
    }
    var rect = NSRect(x: 0, y: 0, width: 600, height: 800)
    let source = sample.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    let work = FileManager.default.temporaryDirectory.appendingPathComponent("shift-demo-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: work) }
    let input = work.appendingPathComponent("Field notes.png")
    try Converter.encode(source, type: .png, quality: 1).write(to: input)
    let pdf = try Converter.convert(input, action: .pdf)[0]
    let jpg = try Converter.convert(pdf, action: .jpg)[0]
    let raster = try Converter.images(jpg)[0]
    try write(raster, "document.png")
    var options = EditOptions()
    options.vertical = 0.38
    let square = try Converter.crop(raster, options: options)
    try write(square, "cropped.png")
    options.padding = 0.17
    options.color = NSColor(calibratedRed: 0.76, green: 0.79, blue: 0.98, alpha: 1)
    try write(try Converter.background(square, options: options), "background.png")

    func wheel(_ files: [URL], _ tools: Bool, _ name: String) throws {
        let actions = Action.available(for: files, tools: tools).filter { $0 != .pdf || !files.contains(where: { $0.pathExtension.lowercased() == "pdf" }) }
        for selection in -1..<actions.count {
            let view = WheelView(frame: NSRect(x: 0, y: 0, width: 390, height: 440))
            view.urls = files; view.actions = actions; view.tools = tools
            view.selected = selection < 0 ? nil : selection
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let state = selection < 0 ? "idle" : actions[selection].rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(name)-\(state).png"))
        }
    }
    try wheel([pdf], false, "formats")
    try wheel([jpg], true, "tools")

    func editor(_ action: Action, _ squareImage: Bool, _ name: String) throws {
        let model = AppModel()
        model.files = [jpg]
        model.editImage = squareImage ? square : raster
        model.editOptions = options
        if action == .crop { model.editOptions.aspect = 1; model.editOptions.vertical = 0.38 }
        let hosting = NSHostingView(rootView: EditorView(model: model, action: action).environment(\.colorScheme, .light))
        let size = NSSize(width: 540, height: action == .crop ? 614 : 584)
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -10000, y: -10000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
        window.orderOut(nil)
    }
    try editor(.crop, false, "editor-crop.png")
    try editor(.background, true, "editor-background.png")
    print("Exported native wheel states, editors, and real conversion outputs.")
}
