import AppKit
import SwiftUI
import PDFKit
import NpdfKit

final class MainWindowController: NSWindowController {
    private let toolSettings = ToolSettings()
    private var toolbarController: ToolbarController!
    private var splitViewController: MainSplitViewController!
    private var signatureStore: SignatureStore?
    private var pdfViewController: PDFViewController!

    // Keep reference so SwiftUI views don't deallocate
    private var signaturePanelHostingController: NSHostingController<SignaturePanelView>?
    private var captureVC: SignatureCaptureViewController?

    convenience init(document: PDFEditorDocument) {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = CGSize(width: 800, height: 600)
        window.center()
        window.setFrameAutosaveName("NpdfMainWindow")
        self.init(window: window)

        window.title = document.displayName
        signatureStore = try? SignatureStore()

        setupSplitView(document: document)
        setupToolbar(for: window)
        setupKeyboardShortcuts()
    }

    // MARK: - Setup

    private func setupSplitView(document: PDFEditorDocument) {
        splitViewController = MainSplitViewController(
            toolSettings: toolSettings,
            document: document,
            signatureStore: signatureStore,
            onNewSignature: { [weak self] in self?.presentSignatureCapture() },
            onSignatureSelected: { [weak self] image in
                self?.pdfViewController?.pendingSignatureImage = image
                self?.toolSettings.currentTool = .signature
            }
        )
        pdfViewController = splitViewController.pdfViewController
        window?.contentViewController = splitViewController
    }

    private func setupToolbar(for window: NSWindow) {
        toolbarController = ToolbarController(toolSettings: toolSettings)
        toolbarController.windowController = self
        window.toolbar = toolbarController.makeToolbar(for: window)
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified
    }

    private func setupKeyboardShortcuts() {
        // Keyboard shortcuts are wired via menu items in Info.plist / MainMenu.xib
        // Additional shortcuts registered here via NSEvent monitors
    }

    // MARK: - Actions

    @IBAction func openDocument(_ sender: Any?) {
        npdfLog("[TOOLBAR] Open document", .ui)
        NSDocumentController.shared.openDocument(sender)
    }

    @IBAction func saveDocument(_ sender: Any?) {
        npdfLog("[TOOLBAR] Save document", .ui)
        document?.save(withDelegate: nil, didSave: nil, contextInfo: nil)
    }

    @IBAction func zoomIn(_ sender: Any?) {
        npdfLog("[TOOLBAR] Zoom in", .ui)
        pdfViewController?.zoomIn()
    }

    @IBAction func zoomOut(_ sender: Any?) {
        npdfLog("[TOOLBAR] Zoom out", .ui)
        pdfViewController?.zoomOut()
    }

    @IBAction func zoomActualSize(_ sender: Any?) {
        npdfLog("[TOOLBAR] Zoom actual size", .ui)
        pdfViewController?.zoomToActualSize()
    }

    @IBAction func toggleSignaturePanel(_ sender: Any?) {
        npdfLog("[TOOLBAR] Toggle signature panel", .ui)
        splitViewController.toggleSignaturePanel()
    }

    @IBAction func openLogFile(_ sender: Any?) {
        npdfLog("[TOOLBAR] Opening log file", .ui)
        NSWorkspace.shared.open(URL(fileURLWithPath: NpdfLogger.logFilePath))
    }

    // MARK: - Signature Capture

    private func presentSignatureCapture() {
        npdfLog("[SIGNATURE] Opening capture sheet", .signature)
        let vc = SignatureCaptureViewController()
        vc.onCapture = { [weak self] image in
            guard let self, let store = self.signatureStore else { return }
            let count = store.loadAll().count + 1
            _ = try? store.save(image, name: "Signature \(count)")
            npdfLog("[SIGNATURE] Captured and saved signature #\(count)", .signature)
            self.splitViewController.reloadSignaturePanel()
        }
        captureVC = vc
        window?.contentViewController?.presentAsSheet(vc)
    }
}
