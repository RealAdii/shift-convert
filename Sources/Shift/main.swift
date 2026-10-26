import AppKit

let app = NSApplication.shared
if CommandLine.arguments.contains("--self-test") {
    do { try selfTest(); print("All conversion and wheel checks passed."); exit(0) }
    catch { fputs("SELF TEST FAILED: \(error)\n", stderr); exit(1) }
}
if CommandLine.arguments.contains("--render-preview") {
    let view = WheelView(frame: NSRect(x: 0, y: 0, width: 390, height: 440))
    view.urls = [URL(fileURLWithPath: "/Summer afternoon.png")]
    view.actions = [.png, .jpg, .pdf, .heic, .tiff, .bmp]
    view.selected = 1
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/shift-wheel.png"))
    exit(0)
}
if let index = CommandLine.arguments.firstIndex(of: "--demo-assets"), CommandLine.arguments.count > index + 1 {
    do {
        NSApp.setActivationPolicy(.prohibited)
        try exportDemoAssets(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        exit(0)
    } catch { fputs("Demo export failed: \(error)\n", stderr); exit(1) }
}
let delegate = AppDelegate()
app.delegate = delegate
if CommandLine.arguments.contains("--render-window") {
    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    RunLoop.main.run(until: Date().addingTimeInterval(1))
    let view = delegate.mainWindow.contentView!
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/shift-window.png"))
    exit(0)
}
app.run()
