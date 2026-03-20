import AppKit
import PDFKit
import NpdfKit

final class PDFEditorDocument: NSDocument {
    var pdfDocument: PDFDocument?
    private(set) var annotationManager: AnnotationManager!
    private let loader = PDFLoader()

    override init() {
        super.init()
        annotationManager = AnnotationManager(undoManager: undoManager)
    }

    // MARK: - NSDocument overrides

    override class var autosavesInPlace: Bool { return true }

    override func makeWindowControllers() {
        let wc = MainWindowController(document: self)
        addWindowController(wc)
        wc.showWindow(nil)
    }

    override func read(from url: URL, ofType typeName: String) throws {
        // Synchronous read required by NSDocument; heavy lifting is done async in makeWindowControllers.
        guard let doc = PDFDocument(url: url) else {
            npdfLog("ERROR: Could not open PDF at \(url.lastPathComponent)", .error)
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: unimpErr,
                userInfo: [NSLocalizedDescriptionKey: "Could not open PDF at \(url.lastPathComponent)"]
            )
        }
        pdfDocument = doc
        npdfLog("PDF loaded: \(url.lastPathComponent) — \(doc.pageCount) page(s)", .document)
    }

    override func write(to url: URL, ofType typeName: String) throws {
        guard let pdfDocument else {
            npdfLog("ERROR: Save attempted with no document loaded", .error)
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
                          userInfo: [NSLocalizedDescriptionKey: "No PDF document loaded."])
        }
        guard pdfDocument.write(to: url) else {
            npdfLog("ERROR: Failed to write PDF to \(url.lastPathComponent)", .error)
            throw NSError(domain: NSOSStatusErrorDomain, code: writErr,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to write PDF to \(url.lastPathComponent)"])
        }
        npdfLog("PDF saved: \(url.lastPathComponent)", .document)
    }

    override class var readableTypes: [String] {
        return ["com.adobe.pdf"]
    }

    override class func isNativeType(_ type: String) -> Bool {
        return type == "com.adobe.pdf"
    }
}
