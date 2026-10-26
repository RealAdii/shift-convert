import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers

struct ConversionFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum Action: String, CaseIterable, Identifiable {
    case png = "PNG", jpg = "JPG", pdf = "PDF", heic = "HEIC", tiff = "TIFF", bmp = "BMP", gif = "GIF", txt = "TXT"
    case crop = "Crop", background = "Add background", compress = "Compress"
    var id: String { rawValue }
    var ext: String { self == .background ? "png" : self == .crop || self == .compress ? "jpg" : rawValue.lowercased() }
    var symbol: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .txt: return "text.alignleft"
        case .crop: return "crop"
        case .background: return "square.on.square"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        default: return "photo"
        }
    }
    var type: UTType? {
        switch self {
        case .png: return .png
        case .jpg, .compress, .crop: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        default: return nil
        }
    }
    static var writable: Set<String> { Set(CGImageDestinationCopyTypeIdentifiers() as! [String]) }
    static func available(for urls: [URL], tools: Bool = false) -> [Action] {
        guard !urls.isEmpty else { return [] }
        let actions: [Action] = tools ? [.crop, .background, .compress] : [.png, .jpg, .pdf, .heic, .tiff, .bmp, .gif, .txt]
        return actions.filter { action in
            if let type = action.type, !writable.contains(type.identifier) { return false }
            return urls.allSatisfy { url in
                let pdf = url.pathExtension.lowercased() == "pdf"
                let image = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
                if action == .txt { return pdf }
                if action == .crop || action == .background { return image }
                return pdf || image
            }
        }
    }
}

struct EditOptions {
    var aspect: Double = 1
    var cropScale: Double = 1
    var horizontal: Double = 0.5
    var vertical: Double = 0.5
    var padding: Double = 0.12
    var color: NSColor = NSColor(calibratedRed: 0.94, green: 0.49, blue: 0.32, alpha: 1)
    var corner: Double = 0.06
}

struct BatchResult {
    var files: [URL] = []
    var errors: [String] = []
}

enum Converter {
    static func run(_ urls: [URL], action: Action, options: EditOptions = EditOptions()) -> BatchResult {
        var result = BatchResult()
        for url in urls {
            autoreleasepool {
                do { result.files += try convert(url, action: action, options: options) }
                catch { result.errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
            }
        }
        return result
    }

    static func convert(_ input: URL, action: Action, options: EditOptions = EditOptions()) throws -> [URL] {
        guard Action.available(for: [input], tools: [.crop, .background, .compress].contains(action)).contains(action) else {
            throw ConversionFailure(message: "This file does not support \(action.rawValue).")
        }
        let isPDF = input.pathExtension.lowercased() == "pdf"
        if action == .txt {
            guard let doc = PDFDocument(url: input), !doc.isLocked else { throw ConversionFailure(message: "Cannot open this PDF. It may be password protected.") }
            let text = (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ConversionFailure(message: "No selectable text found. Scanned PDFs need OCR, which is not included yet.") }
            return [try save(Data(text.utf8), beside: input, ext: "txt")]
        }
        if action == .pdf && isPDF {
            throw ConversionFailure(message: "This file is already a PDF. Choose another format.")
        }
        let pages = try images(input)
        if action == .pdf || (action == .compress && isPDF) {
            let doc = PDFDocument()
            for (index, original) in pages.enumerated() {
                let image = action == .compress ? try jpegRoundTrip(original, quality: 0.55) : original
                guard let page = PDFPage(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))) else { throw ConversionFailure(message: "Cannot create the PDF page.") }
                doc.insert(page, at: index)
            }
            guard let data = doc.dataRepresentation() else { throw ConversionFailure(message: "Cannot encode this PDF.") }
            return [try save(data, beside: input, ext: "pdf", suffix: action == .compress ? " Compressed" : "")]
        }
        var outputs: [URL] = []
        do {
            for (index, original) in pages.enumerated() {
                let image: CGImage
                switch action {
                case .crop: image = try crop(original, options: options)
                case .background: image = try background(original, options: options)
                default: image = original
                }
                guard let type = action.type ?? (action == .background ? UTType.png : nil) else { throw ConversionFailure(message: "No encoder for this format.") }
                let data = try encode(image, type: type, quality: action == .compress ? 0.55 : 0.9)
                let suffix = (pages.count > 1 ? " Page \(index + 1)" : "") + (action == .crop ? " Cropped" : action == .background ? " Background" : action == .compress ? " Compressed" : "")
                outputs.append(try save(data, beside: input, ext: action == .background ? "png" : action.ext, suffix: suffix))
            }
        } catch {
            // Remove only the new outputs created by this failed conversion.
            for output in outputs { try? FileManager.default.removeItem(at: output) }
            throw error
        }
        return outputs
    }

    static func images(_ url: URL) throws -> [CGImage] {
        if url.pathExtension.lowercased() == "pdf" {
            guard let doc = PDFDocument(url: url), !doc.isLocked, doc.pageCount > 0 else { throw ConversionFailure(message: "Cannot read this PDF. Check whether it is password protected.") }
            guard doc.pageCount <= 100 else { throw ConversionFailure(message: "This version supports PDFs with up to 100 pages per file.") }
            var totalPixels = 0.0
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let rect = page.bounds(for: .mediaBox)
                guard rect.width > 0, rect.height > 0, rect.width.isFinite, rect.height.isFinite else {
                    throw ConversionFailure(message: "This PDF has an invalid page size.")
                }
                let factor = min(2, 3000 / max(rect.width, rect.height))
                totalPixels += rect.width * rect.height * factor * factor
            }
            guard totalPixels <= 80_000_000 else {
                throw ConversionFailure(message: "This PDF exceeds the 80 megapixel batch limit. Split it into smaller documents first.")
            }
            return try (0..<doc.pageCount).map { i in
                guard let page = doc.page(at: i) else { throw ConversionFailure(message: "Cannot read page \(i + 1).") }
                let rect = page.bounds(for: .mediaBox)
                let factor = min(2, 3000 / max(rect.width, rect.height))
                let size = NSSize(width: max(1, rect.width * factor), height: max(1, rect.height * factor))
                var proposed = NSRect(origin: .zero, size: size)
                guard let cg = page.thumbnail(of: size, for: .mediaBox).cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { throw ConversionFailure(message: "Cannot render page \(i + 1).") }
                return cg
            }
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { throw ConversionFailure(message: "Cannot decode this image.") }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 8192, kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { throw ConversionFailure(message: "Cannot decode this image.") }
        return [image]
    }

    static func context(width: Int, height: Int, alpha: Bool = true) throws -> CGContext {
        guard width > 0, height > 0, width * height <= 90_000_000,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue) else { throw ConversionFailure(message: "This image is too large to process safely.") }
        return ctx
    }

    static func encode(_ image: CGImage, type: UTType, quality: Double) throws -> Data {
        var image = image
        if type == .jpeg || type == .bmp || type == .heic {
            let ctx = try context(width: image.width, height: image.height, alpha: false)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            image = ctx.makeImage()!
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { throw ConversionFailure(message: "This Mac cannot encode \(type.preferredFilenameExtension ?? type.identifier).") }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ConversionFailure(message: "The image encoder failed.") }
        return data as Data
    }

    static func jpegRoundTrip(_ image: CGImage, quality: Double) throws -> CGImage {
        let data = try encode(image, type: .jpeg, quality: quality)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let output = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ConversionFailure(message: "Cannot compress this image.") }
        return output
    }

    static func cropRect(_ image: CGImage, options: EditOptions) -> CGRect {
        let w = Double(image.width), h = Double(image.height)
        let width = min(w, h * options.aspect) * options.cropScale
        let height = width / options.aspect
        return CGRect(x: (w - width) * options.horizontal, y: (h - height) * options.vertical, width: width, height: height).integral.intersection(CGRect(x: 0, y: 0, width: w, height: h))
    }

    static func crop(_ image: CGImage, options: EditOptions) throws -> CGImage {
        guard let output = image.cropping(to: cropRect(image, options: options)) else { throw ConversionFailure(message: "Cannot crop this image.") }
        return output
    }

    static func background(_ image: CGImage, options: EditOptions) throws -> CGImage {
        let pad = Double(max(image.width, image.height)) * options.padding
        let w = Int(Double(image.width) + 2 * pad), h = Int(Double(image.height) + 2 * pad)
        let ctx = try context(width: w, height: h)
        ctx.setFillColor(options.color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let rect = CGRect(x: pad, y: pad, width: Double(image.width), height: Double(image.height))
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: Double(min(image.width, image.height)) * options.corner, cornerHeight: Double(min(image.width, image.height)) * options.corner, transform: nil))
        ctx.clip()
        ctx.draw(image, in: rect)
        return ctx.makeImage()!
    }

    static func save(_ data: Data, beside input: URL, ext: String, suffix: String = "") throws -> URL {
        let directory = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + suffix
        let temporary = directory.appendingPathComponent(".shift-" + UUID().uuidString)
        try data.write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }
        for index in 0..<10_000 {
            let name = base + (index == 0 ? "" : " (\(index + 1))") + "." + ext
            let output = directory.appendingPathComponent(name)
            do { try FileManager.default.moveItem(at: temporary, to: output); return output }
            catch {
                if FileManager.default.fileExists(atPath: output.path) { continue }
                throw error
            }
        }
        throw ConversionFailure(message: "Too many files share this name.")
    }
}
