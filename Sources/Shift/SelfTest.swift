import AppKit
import PDFKit
import UniformTypeIdentifiers

func selfTest() throws {
    func check(_ value: Bool, _ message: String) throws {
        if !value { throw ConversionFailure(message: message) }
    }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("shift-tests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let ctx = try Converter.context(width: 160, height: 100)
    ctx.setFillColor(NSColor.systemOrange.cgColor)
    ctx.fill(CGRect(x: 20, y: 20, width: 100, height: 60))
    let image = ctx.makeImage()!
    let input = dir.appendingPathComponent("sample.png")
    let original = try Converter.encode(image, type: .png, quality: 1)
    try original.write(to: input)
    for action in [Action.jpg, .png, .tiff, .bmp, .gif, .heic] where Action.available(for: [input]).contains(action) {
        let result = try Converter.convert(input, action: action)
        let decoded = try Converter.images(result[0])[0]
        try check(decoded.width == 160 && decoded.height == 100, "Wrong dimensions for \(action)")
        print("PASS \(action.rawValue) encoding and decoding")
    }
    try check(try Data(contentsOf: input) == original, "Original image was changed")
    let pdfURL = try Converter.convert(input, action: .pdf)[0]
    try check(PDFDocument(url: pdfURL)?.pageCount == 1, "Image to PDF failed")
    let doc = PDFDocument()
    doc.insert(PDFPage(image: NSImage(cgImage: image, size: .zero))!, at: 0)
    doc.insert(PDFPage(image: NSImage(cgImage: image, size: .zero))!, at: 1)
    let multipage = dir.appendingPathComponent("two.pdf")
    try doc.dataRepresentation()!.write(to: multipage)
    let pages = try Converter.convert(multipage, action: .png)
    try check(pages.count == 2, "PDF conversion dropped pages")
    let compressed = try Converter.convert(multipage, action: .compress)
    try check(PDFDocument(url: compressed[0])?.pageCount == 2, "PDF compression dropped pages")
    print("PASS image to PDF, multipage PDF export, PDF compression")
    let textPDF = dir.appendingPathComponent("text.pdf")
    let pdfData = NSMutableData()
    let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
    var box = CGRect(x: 0, y: 0, width: 400, height: 200)
    let pdf = CGContext(consumer: consumer, mediaBox: &box, nil)!
    pdf.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: false)
    ("Hello Shift" as NSString).draw(at: NSPoint(x: 30, y: 100), withAttributes: [.font: NSFont.systemFont(ofSize: 20)])
    NSGraphicsContext.restoreGraphicsState()
    pdf.endPDFPage(); pdf.closePDF()
    try (pdfData as Data).write(to: textPDF)
    let text = try Converter.convert(textPDF, action: .txt)[0]
    try check(try String(contentsOf: text).contains("Hello Shift"), "PDF text extraction failed")
    print("PASS selectable PDF text extraction")
    let cropped = try Converter.convert(input, action: .crop)[0]
    let square = try Converter.images(cropped)[0]
    try check(square.width == 100 && square.height == 100, "Crop aspect ratio failed")
    let bg = try Converter.convert(input, action: .background)[0]
    try check(try Converter.images(bg)[0].width > 160, "Background padding failed")
    let result = Converter.run([input, dir.appendingPathComponent("missing.png")], action: .jpg)
    try check(result.files.count == 1 && result.errors.count == 1, "Batch partial failure handling failed")
    let again = try Converter.convert(input, action: .jpg)[0]
    try check(again != result.files[0], "Collision protection failed")
    try check(try Data(contentsOf: input) == original, "Original was modified")
    print("PASS crop, background, partial errors, filename collisions, original preservation")
    let wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 390, height: 440))
    wheel.actions = [.png, .jpg, .pdf, .heic, .tiff, .bmp]
    try check(wheel.selection(at: wheel.center) == nil, "Center must not convert")
    try check(wheel.selection(at: .zero) == nil, "Outside must not convert")
    for i in wheel.actions.indices {
        let angle = -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(wheel.actions.count)
        let point = NSPoint(x: wheel.center.x + 115 * cos(angle), y: wheel.center.y + 115 * sin(angle))
        try check(wheel.selection(at: point) == i, "Wheel selection mismatch at \(i)")
    }
    print("PASS radial hit testing for every sector and dead zones")
}
