import AppKit
import PDFKit
import NpdfKit
import Combine

final class PDFViewController: NSViewController {
    let pdfView = PDFView()
    private var overlayViews: [PDFPage: AnnotationOverlayView] = [:]

    var toolSettings: ToolSettings?
    var annotationManager: AnnotationManager?
    var signatureStore: SignatureStore?
    var pendingSignatureImage: NSImage? {
        didSet {
            // Propagate to all active overlay views
            for overlay in overlayViews.values {
                overlay.pendingSignatureImage = pendingSignatureImage
            }
        }
    }

    // Empty state
    private let emptyStateView = EmptyStateView()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPDFView()
        setupEmptyState()
        observeScrollNotifications()
    }

    // MARK: - Setup

    private func setupPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1.0)
        pdfView.isHidden = true

        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if #available(macOS 12.0, *) {
            pdfView.pageOverlayViewProvider = self
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(pageChanged),
            name: .PDFViewPageChanged, object: pdfView
        )
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.onOpenPDF = { [weak self] in
            self?.openPDF()
        }
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func observeScrollNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(visiblePagesChanged),
            name: .PDFViewVisiblePagesChanged, object: pdfView
        )
    }

    @objc private func pageChanged() { updateOverlays() }
    @objc private func visiblePagesChanged() { updateOverlays() }

    private func updateOverlays() {
        guard let doc = pdfView.document else { return }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            overlayViews[page]?.toolSettings = toolSettings
            overlayViews[page]?.annotationManager = annotationManager
            overlayViews[page]?.pdfView = pdfView
            overlayViews[page]?.page = page
        }
    }

    // MARK: - Public API

    func load(_ pdfDocument: PDFDocument) {
        pdfView.document = pdfDocument
        pdfView.isHidden = false
        emptyStateView.isHidden = true
    }

    func zoomIn() { pdfView.zoomIn(nil) }
    func zoomOut() { pdfView.zoomOut(nil) }
    func zoomToActualSize() { pdfView.scaleFactor = 1.0 }

    // MARK: - Open

    private func openPDF() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.pdf]
        panel.title = "Open PDF"
        panel.beginSheetModal(for: view.window!) { response in
            guard response == .OK, let url = panel.url else { return }
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
    }
}

// MARK: - PDFPageOverlayViewProvider

@available(macOS 12.0, *)
extension PDFViewController: PDFPageOverlayViewProvider {
    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> NSView? {
        if let existing = overlayViews[page] { return existing }
        let overlay = AnnotationOverlayView()
        overlay.toolSettings = toolSettings
        overlay.annotationManager = annotationManager
        overlay.pdfView = pdfView
        overlay.page = page
        overlayViews[page] = overlay
        return overlay
    }

    func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: NSView, for page: PDFPage) {
        guard let overlay = overlayView as? AnnotationOverlayView else { return }
        overlay.toolSettings = toolSettings
        overlay.annotationManager = annotationManager
        overlay.pdfView = pdfView
        overlay.page = page
        overlay.pendingSignatureImage = pendingSignatureImage
    }

    func pdfView(_ view: PDFView, willEndDisplayingOverlayView overlayView: NSView, for page: PDFPage) {}
}

// MARK: - EmptyStateView

final class EmptyStateView: NSView {
    var onOpenPDF: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1.0).cgColor

        // PDF icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .thin)
        iconView.image = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.3)
        addSubview(iconView)

        // Title label
        let titleLabel = NSTextField(labelWithString: "No PDF Open")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .medium)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        titleLabel.alignment = .center
        addSubview(titleLabel)

        // Open button
        let openButton = NSButton(title: "Open PDF…", target: self, action: #selector(openTapped))
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.bezelStyle = .rounded
        openButton.controlSize = .large
        openButton.keyEquivalent = "\r"
        addSubview(openButton)

        // Drag hint
        let hintLabel = NSTextField(labelWithString: "or drag a PDF file here")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        hintLabel.alignment = .center
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            openButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            openButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 140),

            hintLabel.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 10),
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])

        // Register for drag and drop
        registerForDraggedTypes([.fileURL])
    }

    @objc private func openTapped() {
        onOpenPDF?()
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              urls.first?.pathExtension.lowercased() == "pdf" else { return [] }
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderWidth = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderWidth = 0
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              let url = urls.first, url.pathExtension.lowercased() == "pdf" else { return false }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        return true
    }
}
