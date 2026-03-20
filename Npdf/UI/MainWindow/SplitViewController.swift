import AppKit
import SwiftUI
import PDFKit
import NpdfKit

final class MainSplitViewController: NSSplitViewController {
    let pdfViewController: PDFViewController
    private let thumbnailSidebarVC: NSViewController
    private let signatureSidebarVC: NSViewController
    private let signatureViewModel: SignaturePanelViewModel?

    init(
        toolSettings: ToolSettings,
        document: PDFEditorDocument,
        signatureStore: SignatureStore?,
        onNewSignature: @escaping () -> Void,
        onSignatureSelected: @escaping (NSImage) -> Void
    ) {
        // PDF Viewer (center)
        let pdfVC = PDFViewController()
        pdfVC.toolSettings = toolSettings
        pdfVC.annotationManager = document.annotationManager
        pdfVC.signatureStore = signatureStore
        self.pdfViewController = pdfVC

        // Thumbnail Sidebar (left)
        let sidebarVC = NSViewController()
        sidebarVC.view = ThumbnailSidebarView()
        thumbnailSidebarVC = sidebarVC

        // Signature Panel (right) — SwiftUI backed by ObservableObject view model
        let store = signatureStore ?? (try? SignatureStore())
        let viewModel = store.map { SignaturePanelViewModel(store: $0) }
        self.signatureViewModel = viewModel

        let panelView = SignaturePanelView(
            viewModel: viewModel ?? SignaturePanelViewModel(store: try! SignatureStore()),
            toolSettings: toolSettings,
            onSignatureSelected: onSignatureSelected,
            onNewSignature: onNewSignature
        )
        signatureSidebarVC = NSHostingController(rootView: panelView)

        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    private let document: PDFEditorDocument

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let leftItem = NSSplitViewItem(sidebarWithViewController: thumbnailSidebarVC)
        leftItem.minimumThickness = 130
        leftItem.maximumThickness = 200
        leftItem.canCollapse = true
        addSplitViewItem(leftItem)

        let centerItem = NSSplitViewItem(viewController: pdfViewController)
        centerItem.minimumThickness = 400
        addSplitViewItem(centerItem)

        let rightItem = NSSplitViewItem(sidebarWithViewController: signatureSidebarVC)
        rightItem.minimumThickness = 160
        rightItem.maximumThickness = 240
        rightItem.canCollapse = true
        rightItem.isCollapsed = true
        addSplitViewItem(rightItem)

        splitView.dividerStyle = .thin
        splitView.isVertical = true
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if let pdfDoc = document.pdfDocument {
            pdfViewController.load(pdfDoc)
        }

        if let thumbView = thumbnailSidebarVC.view as? ThumbnailSidebarView {
            thumbView.pdfView = pdfViewController.pdfView
        }
    }

    // MARK: - Signature panel

    func reloadSignaturePanel() {
        // View model is a reference type — @Published fires and SwiftUI updates automatically
        signatureViewModel?.reload()
        showSignaturePanel()
    }

    func showSignaturePanel() {
        guard let item = splitViewItems.last, item.isCollapsed else { return }
        item.isCollapsed = false
        view.layoutSubtreeIfNeeded()
        splitView.setPosition(splitView.frame.width - 200, ofDividerAt: splitView.subviews.count - 2)
    }

    func toggleSignaturePanel() {
        guard let item = splitViewItems.last else { return }
        if item.isCollapsed {
            showSignaturePanel()
        } else {
            item.isCollapsed = true
            view.layoutSubtreeIfNeeded()
        }
    }
}
