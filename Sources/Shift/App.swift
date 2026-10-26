import AppKit
import SwiftUI
import Combine

final class AppModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var busy = false
    @Published var outputs: [URL] = []
    @Published var errors: [String] = []
    @Published var status = "Ready when you are."
    @Published var enabled = true
    @Published var editing: Action?
    @Published var editOptions = EditOptions()
    var editImage: CGImage?

    func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]
        if panel.runModal() == .OK { files = panel.urls; errors = []; status = "Choose a format below." }
    }
    func perform(_ urls: [URL], _ action: Action) {
        guard !busy else { return }
        files = urls
        if action == .crop || action == .background {
            do {
                guard let first = urls.first else { return }
                editImage = try Converter.images(first).first
                editOptions = EditOptions()
                editing = action
                (NSApp.delegate as? AppDelegate)?.showWindow()
            } catch { errors = [error.localizedDescription] }
        } else { convert(action) }
    }
    func convert(_ action: Action) {
        guard !busy, !files.isEmpty else { return }
        busy = true
        editing = nil
        errors = []
        outputs = []
        status = "Creating \(action.rawValue.lowercased()) files…"
        let inputs = files, options = editOptions
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Converter.run(inputs, action: action, options: options)
            DispatchQueue.main.async {
                self.busy = false
                self.outputs = result.files
                self.errors = result.errors
                self.status = result.files.isEmpty ? "No files created." : "Saved \(result.files.count) \(result.files.count == 1 ? "file" : "files") beside the originals."
                (NSApp.delegate as? AppDelegate)?.showWindow()
                if let window = NSApp.mainWindow {
                    NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: [.announcement: self.status, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    var mainWindow: NSWindow!
    var statusItem: NSStatusItem!
    var panel: WheelPanel!
    var wheel: WheelView!
    var timer: Timer?
    var wasShift = false
    var wasEscape = false
    var idleDragChangeCount = NSPasteboard(name: .drag).changeCount
    var releasedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = Self.icon()
        wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 390, height: 440))
        panel = WheelPanel(view: wheel)
        panel.setContentSize(NSSize(width: 390, height: 440))
        wheel.onDrop = { [weak self] files, action in
            guard let self else { return }
            self.panel.orderOut(nil)
            DispatchQueue.main.async { self.model.perform(files, action) }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "shift", accessibilityDescription: "Shift file converter")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Shift", action: #selector(showWindow), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Choose files…", action: #selector(chooseFiles), keyEquivalent: "n").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Pause drag shortcut", action: #selector(toggleEnabled(_:)), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Shift", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 690), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        mainWindow.title = "Shift"
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.isReleasedWhenClosed = false
        mainWindow.contentView = NSHostingView(rootView: MainView(model: model))
        mainWindow.center()
        let timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        showWindow()
    }
    @objc func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }
    @objc func chooseFiles() { showWindow(); model.choose() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggleEnabled(_ sender: NSMenuItem) {
        model.enabled.toggle()
        sender.title = model.enabled ? "Pause drag shortcut" : "Resume drag shortcut"
        if !model.enabled { panel.orderOut(nil) }
    }
    func tick() {
        let shift = CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
        let escape = CGEventSource.keyState(.combinedSessionState, key: 53)
        let dragging = NSEvent.pressedMouseButtons & 1 != 0
        defer {
            wasShift = shift
            wasEscape = escape
            if !dragging { idleDragChangeCount = NSPasteboard(name: .drag).changeCount }
        }
        if escape && !wasEscape { panel.orderOut(nil) }
        guard model.enabled, !model.busy else { return }
        if shift && !wasShift && dragging {
            let pasteboard = NSPasteboard(name: .drag)
            guard pasteboard.changeCount != idleDragChangeCount else { return }
            let urls = WheelView.files(pasteboard)
            guard !urls.isEmpty else { return }
            let tools = panel.isVisible ? !wheel.tools : false
            let actions = Action.available(for: urls, tools: tools).filter { $0 != .pdf || !urls.contains(where: { $0.pathExtension.lowercased() == "pdf" }) }
            guard !actions.isEmpty else { panel.orderOut(nil); return }
            wheel.urls = urls
            wheel.tools = tools
            wheel.actions = actions
            wheel.selected = nil
            wheel.needsDisplay = true
            if !panel.isVisible {
                let mouse = NSEvent.mouseLocation
                let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main!
                let frame = screen.visibleFrame
                let x = min(max(mouse.x - 195, frame.minX + 8), frame.maxX - 398)
                let y = min(max(mouse.y - 215, frame.minY + 8), frame.maxY - 448)
                panel.setFrameOrigin(NSPoint(x: x, y: y))
                panel.orderFrontRegardless()
            }
            releasedAt = nil
        }
        if panel.isVisible && !dragging {
            if releasedAt == nil { releasedAt = Date() }
            if Date().timeIntervalSince(releasedAt!) > 0.2 { panel.orderOut(nil) }
        } else { releasedAt = nil }
    }
    static func icon() -> NSImage {
        NSImage(size: NSSize(width: 256, height: 256), flipped: false) { rect in
            NSColor(calibratedRed: 0.94, green: 0.38, blue: 0.20, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 55, yRadius: 55).fill()
            let symbol = NSImage(systemSymbolName: "shift", accessibilityDescription: nil)!
            let tinted = NSImage(size: symbol.size, flipped: false) { box in
                symbol.draw(in: box)
                NSColor.white.setFill()
                box.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: rect.insetBy(dx: 57, dy: 57))
            return true
        }
    }
}

let ink = Color(red: 0.16, green: 0.17, blue: 0.16)
let accent = Color(red: 0.84, green: 0.28, blue: 0.12)
let paper = Color(red: 0.97, green: 0.96, blue: 0.93)

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var dropTarget = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("shift", systemImage: "shift").font(.system(size: 23, weight: .bold, design: .rounded))
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(model.enabled ? Color.green : Color.gray).frame(width: 6, height: 6)
                    Text(model.enabled ? "Ready in your menu bar" : "Shortcut paused").font(.system(size: 11, weight: .medium))
                }.foregroundStyle(.secondary)
            }.padding(.bottom, 27)
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A little shortcut.\nA lot less friction.").font(.system(size: 35, weight: .semibold, design: .rounded)).tracking(-1.2).fixedSize(horizontal: false, vertical: true)
                    Text("Drag a file. Tap Shift.\nDrop it onto a format.").font(.system(size: 16)).lineSpacing(5).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 7) {
                        Text("⇧").font(.system(size: 21, weight: .medium)).frame(width: 42, height: 36).background(.white, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.1)))
                        Text("again for editing tools").font(.system(size: 11)).foregroundStyle(.secondary)
                    }.padding(.top, 3)
                }.frame(maxWidth: .infinity, alignment: .leading)
                MiniWheel().frame(width: 280, height: 265).accessibilityHidden(true)
            }.padding(.bottom, 23)
            VStack(spacing: 12) {
                HStack(spacing: 13) {
                    Image(systemName: model.files.isEmpty ? "square.and.arrow.down" : "doc.on.doc").font(.system(size: 24, weight: .light)).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.files.isEmpty ? "Or start right here" : model.files.count == 1 ? model.files[0].lastPathComponent : "\(model.files.count) files selected").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text(model.files.isEmpty ? "Drop images or PDFs into this window." : "Choose a format or an editing tool below.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose files…") { model.choose() }.controlSize(.large).disabled(model.busy)
                }
                if !model.files.isEmpty {
                    Divider()
                    HStack(spacing: 7) {
                        ForEach(Action.available(for: model.files).filter { $0 != .pdf || !model.files.contains(where: { $0.pathExtension.lowercased() == "pdf" }) }) { action in
                            Button(action.rawValue) { model.perform(model.files, action) }.buttonStyle(.bordered).disabled(model.busy)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        ForEach(Action.available(for: model.files, tools: true)) { action in
                            Button { model.perform(model.files, action) } label: { Label(action.rawValue, systemImage: action.symbol) }.disabled(model.busy)
                        }
                        Spacer(minLength: 0)
                    }.controlSize(.small)
                    if model.files.contains(where: { $0.pathExtension.lowercased() == "pdf" }) {
                        Text("PDF compression flattens text, links and vectors. File size may increase.").font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding(18).background(dropTarget ? accent.opacity(0.08) : Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(dropTarget ? accent : .black.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .dropDestination(for: URL.self) { urls, _ in
                guard !model.busy else { return false }
                model.files = urls.filter { $0.isFileURL && !$0.hasDirectoryPath }
                model.errors = Action.available(for: model.files).isEmpty ? ["Choose supported images or PDFs. Mixed batches need a shared output format."] : []
                return !model.files.isEmpty
            } isTargeted: { dropTarget = $0 }
            Spacer(minLength: 18)
            HStack(spacing: 9) {
                if model.busy { ProgressView().controlSize(.small) }
                else { Image(systemName: model.outputs.isEmpty ? "lock" : "checkmark.circle.fill").foregroundStyle(model.outputs.isEmpty ? ink.opacity(0.5) : Color.green) }
                Text(model.status).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if !model.outputs.isEmpty { Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(model.outputs) }.controlSize(.small) }
            }.accessibilityElement(children: .combine)
            if !model.errors.isEmpty {
                ScrollView { VStack(alignment: .leading, spacing: 5) { ForEach(Array(model.errors.enumerated()), id: \.offset) { _, error in Text(error).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled) } } }.frame(maxHeight: 70).padding(.top, 8)
            }
            Divider().padding(.vertical, 15)
            HStack(alignment: .top) {
                Text("ON YOUR MAC. IN YOUR FLOW.").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
                Spacer()
                Text("Local processing · Originals stay intact\nImages up to 8192 px · GIFs use the first frame").font(.system(size: 10)).multilineTextAlignment(.trailing).foregroundStyle(.secondary)
            }
        }.padding(30).frame(width: 780, height: 690).background(paper).foregroundStyle(ink)
        .sheet(item: $model.editing) { action in EditorView(model: model, action: action) }
        .onExitCommand { model.editing = nil }
    }
}

struct MiniWheel: View {
    private let image: NSImage = {
        let wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 390, height: 440))
        wheel.urls = [URL(fileURLWithPath: "/Summer afternoon.png")]
        wheel.actions = [.png, .jpg, .pdf, .heic, .tiff, .bmp]
        wheel.selected = 1
        let bitmap = wheel.bitmapImageRepForCachingDisplay(in: wheel.bounds)!
        wheel.cacheDisplay(in: wheel.bounds, to: bitmap)
        let image = NSImage(size: wheel.bounds.size)
        image.addRepresentation(bitmap)
        return image
    }()
    var body: some View {
        Image(nsImage: image).resizable().scaledToFit()
    }
}

struct EditorView: View {
    @ObservedObject var model: AppModel
    let action: Action
    @State private var preview: NSImage?
    @State private var backgroundColor = Color(red: 0.94, green: 0.49, blue: 0.32)
    init(model: AppModel, action: Action) {
        self.model = model
        self.action = action
        _backgroundColor = State(initialValue: Color(nsColor: model.editOptions.color))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(action.rawValue).font(.title2.bold()); Spacer(); Text("\(model.files.count) \(model.files.count == 1 ? "file" : "files")").foregroundStyle(.secondary) }
            ZStack {
                Color.black.opacity(0.04)
                if let preview { Image(nsImage: preview).resizable().scaledToFit().padding(12) }
            }.frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 12))
            if action == .crop {
                Picker("Aspect ratio", selection: $model.editOptions.aspect) {
                    Text("Square").tag(1.0); Text("4:3").tag(4.0 / 3); Text("16:9").tag(16.0 / 9); Text("Portrait").tag(3.0 / 4)
                }.pickerStyle(.segmented)
                slider("Crop size", value: $model.editOptions.cropScale, range: 0.15...1)
                slider("Horizontal", value: $model.editOptions.horizontal, range: 0...1)
                slider("Vertical", value: $model.editOptions.vertical, range: 0...1)
            } else {
                ColorPicker("Background color", selection: $backgroundColor, supportsOpacity: false)
                slider("Padding", value: $model.editOptions.padding, range: 0.02...0.4)
                slider("Corners", value: $model.editOptions.corner, range: 0...0.25)
            }
            Text("Preview shows the first file. These settings apply to every selected image.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { model.editing = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save \(action == .crop ? "cropped images" : "with background")") { model.convert(action) }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(accent)
            }
        }.padding(24).frame(width: 540).background(paper)
        .onAppear { refresh() }
        .onChange(of: model.editOptions.aspect) { refresh() }
        .onChange(of: model.editOptions.cropScale) { refresh() }
        .onChange(of: model.editOptions.horizontal) { refresh() }
        .onChange(of: model.editOptions.vertical) { refresh() }
        .onChange(of: model.editOptions.padding) { refresh() }
        .onChange(of: model.editOptions.corner) { refresh() }
        .onChange(of: backgroundColor) { model.editOptions.color = NSColor(backgroundColor); refresh() }
    }
    func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack { Text(title).frame(width: 90, alignment: .leading); Slider(value: value, in: range).accessibilityLabel(title) }
    }
    func refresh() {
        guard let original = model.editImage else { return }
        // Limit live previews to 1000 pixels. Final exports use the source image.
        let ratio = min(1, 1000 / Double(max(original.width, original.height)))
        let ctx = try? Converter.context(width: max(1, Int(Double(original.width) * ratio)), height: max(1, Int(Double(original.height) * ratio)))
        ctx?.draw(original, in: CGRect(x: 0, y: 0, width: ctx!.width, height: ctx!.height))
        guard let image = ctx?.makeImage() else { return }
        let result = action == .crop ? try? Converter.crop(image, options: model.editOptions) : try? Converter.background(image, options: model.editOptions)
        if let result { preview = NSImage(cgImage: result, size: .zero) }
    }
}
