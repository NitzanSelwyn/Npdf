import AppKit
import PDFKit

final class ThumbnailSidebarView: NSView {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var thumbnailItems: [ThumbnailItemView] = []

    var pdfView: PDFView? {
        didSet { reload() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .centerX

        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func reload() {
        thumbnailItems.forEach { $0.removeFromSuperview() }
        thumbnailItems = []
        stackView.arrangedSubviews.forEach { stackView.removeArrangedSubview($0); $0.removeFromSuperview() }

        guard let pdfView, let document = pdfView.document else { return }

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let item = ThumbnailItemView(page: page, pageIndex: i, pdfView: pdfView)
            stackView.addArrangedSubview(item)
            thumbnailItems.append(item)
            NSLayoutConstraint.activate([
                item.widthAnchor.constraint(equalToConstant: 120),
                item.heightAnchor.constraint(equalToConstant: 150),
            ])
        }

        // Update stackView frame so scroll view knows content size
        stackView.frame = CGRect(x: 0, y: 0, width: 136, height: CGFloat(document.pageCount) * 158)
    }
}

final class ThumbnailItemView: NSView {
    private let imageView = NSImageView()
    private let pageLabel = NSTextField(labelWithString: "")
    private let page: PDFPage
    private let pageIndex: Int
    private weak var pdfView: PDFView?

    init(page: PDFPage, pageIndex: Int, pdfView: PDFView) {
        self.page = page
        self.pageIndex = pageIndex
        self.pdfView = pdfView
        super.init(frame: .zero)
        setup()
        generateThumbnail()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 3
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.stringValue = "\(pageIndex + 1)"
        pageLabel.alignment = .center
        pageLabel.font = .systemFont(ofSize: 10)
        pageLabel.textColor = .secondaryLabelColor
        addSubview(pageLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            imageView.bottomAnchor.constraint(equalTo: pageLabel.topAnchor, constant: -4),
            pageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            pageLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func generateThumbnail() {
        let thumbnailSize = CGSize(width: 108, height: 130)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let thumbnail = self.page.thumbnail(of: thumbnailSize, for: .cropBox)
            DispatchQueue.main.async {
                self.imageView.image = thumbnail
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        pdfView?.go(to: page)

        // Highlight selected
        superview?.subviews.forEach { ($0 as? ThumbnailItemView)?.layer?.backgroundColor = nil }
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3).cgColor
    }
}
