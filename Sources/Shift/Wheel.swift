import AppKit

final class WheelPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    init(view: WheelView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 390, height: 420), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = view
    }
}

final class WheelView: NSView {
    var urls: [URL] = []
    var actions: [Action] = []
    var tools = false
    var selected: Int? { didSet { if oldValue != selected { needsDisplay = true } } }
    var onDrop: (([URL], Action) -> Void)?
    let center = NSPoint(x: 195, y: 225)
    let outer: CGFloat = 167
    let inner: CGFloat = 65
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        setAccessibilityLabel("Conversion wheel. Drop a file on a format. Use Choose files from the menu for keyboard access.")
    }
    required init?(coder: NSCoder) { fatalError("Not used") }

    func selection(at point: NSPoint) -> Int? {
        guard !actions.isEmpty else { return nil }
        let dx = point.x - center.x, dy = point.y - center.y
        let radius = hypot(dx, dy)
        guard radius >= inner, radius <= outer else { return nil }
        let step = 2 * Double.pi / Double(actions.count)
        var angle = atan2(Double(dy), Double(dx)) + Double.pi / 2 + step / 2
        if angle < 0 { angle += 2 * Double.pi }
        return Int(angle / step) % actions.count
    }

    func wedge(_ index: Int) -> NSBezierPath {
        let step = 2 * Double.pi / Double(actions.count)
        let middle = -Double.pi / 2 + Double(index) * step
        let start = middle - step / 2 + 0.025
        let end = middle + step / 2 - 0.025
        let path = NSBezierPath()
        for i in 0...50 {
            let a = start + (end - start) * Double(i) / 50
            let point = NSPoint(x: center.x + outer * cos(a), y: center.y + outer * sin(a))
            if i == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        for i in 0...50 {
            let a = end - (end - start) * Double(i) / 50
            path.line(to: NSPoint(x: center.x + inner * cos(a), y: center.y + inner * sin(a)))
        }
        path.close()
        return path
    }

    override func draw(_ dirtyRect: NSRect) {
        let back = NSBezierPath(ovalIn: NSRect(x: center.x - outer - 7, y: center.y - outer - 7, width: (outer + 7) * 2, height: (outer + 7) * 2))
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()
        NSColor(calibratedWhite: 0.12, alpha: 0.96).setFill()
        back.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.2).setStroke()
        back.lineWidth = 1
        back.stroke()
        for (i, action) in actions.enumerated() {
            let active = selected == i
            let path = wedge(i)
            (active ? NSColor(calibratedRed: 0.94, green: 0.47, blue: 0.29, alpha: 1) : NSColor(calibratedWhite: 0.93, alpha: 0.97)).setFill()
            path.fill()
            let a = -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(actions.count)
            let p = NSPoint(x: center.x + 116 * cos(a), y: center.y + 116 * sin(a))
            let color: NSColor = active ? .white : NSColor(calibratedWhite: 0.14, alpha: 1)
            if let icon = NSImage(systemSymbolName: action.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 19, weight: .medium)) {
                let tinted = NSImage(size: icon.size, flipped: false) { rect in
                    icon.draw(in: rect)
                    color.setFill()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: NSRect(x: p.x - 10, y: p.y - 20, width: 20, height: 20))
            }
            let title = action == .background ? "Background" : action == .compress && urls.contains(where: { $0.pathExtension.lowercased() == "pdf" }) ? "Flatten PDF" : action.rawValue
            label(title, at: NSPoint(x: p.x, y: p.y + 13), font: .systemFont(ofSize: 12, weight: .semibold), color: color)
        }
        label("⇧", at: NSPoint(x: center.x, y: center.y - 10), font: .systemFont(ofSize: 30, weight: .medium), color: .white)
        label(tools ? "EDIT" : "CONVERT", at: NSPoint(x: center.x, y: center.y + 21), font: .systemFont(ofSize: 9, weight: .bold), color: .white.withAlphaComponent(0.65))
        label(urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files", at: NSPoint(x: center.x, y: 21), font: .systemFont(ofSize: 12, weight: .medium), color: .white, pill: true)
        label(selected.map { "Drop to \(actions[$0].rawValue.lowercased())" } ?? "Drop on a format · Shift for \(tools ? "formats" : "tools")", at: NSPoint(x: center.x, y: 410), font: .systemFont(ofSize: 11, weight: .medium), color: .white, pill: true)
    }

    func label(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, pill: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        let width = min(345, (text as NSString).size(withAttributes: attrs).width + 20)
        let height = ceil(font.ascender - font.descender + font.leading) + 4
        let rect = NSRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
        if pill {
            NSColor(calibratedWhite: 0.1, alpha: 0.93).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: -7, dy: -4), xRadius: 12, yRadius: 12).fill()
        }
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        selected = selection(at: convert(sender.draggingLocation, from: nil))
        return selected == nil ? [] : .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { selected = nil }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { selection(at: convert(sender.draggingLocation, from: nil)) != nil }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let index = selection(at: convert(sender.draggingLocation, from: nil)) else { return false }
        let files = Self.files(sender.draggingPasteboard)
        guard !files.isEmpty else { return false }
        onDrop?(files, actions[index])
        return true
    }
    static func files(_ pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter { !$0.hasDirectoryPath }
    }
}
