import AppKit

/// A panel sheet where the user draws their signature.
final class SignatureCaptureViewController: NSViewController {
    var onCapture: ((NSImage) -> Void)?

    private let canvasView = SignatureCanvasView()
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let instructionLabel = NSTextField(labelWithString: "Draw your signature below")

    override func loadView() {
        view = NSView(frame: CGRect(x: 0, y: 0, width: 480, height: 280))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.font = .systemFont(ofSize: 13)
        view.addSubview(instructionLabel)

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.wantsLayer = true
        canvasView.layer?.backgroundColor = NSColor.white.cgColor
        canvasView.layer?.cornerRadius = 8
        canvasView.layer?.borderColor = NSColor.separatorColor.cgColor
        canvasView.layer?.borderWidth = 1
        view.addSubview(canvasView)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearCanvas)
        view.addSubview(clearButton)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        view.addSubview(cancelButton)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.target = self
        doneButton.action = #selector(done)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            canvasView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 8),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            canvasView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -12),

            clearButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            clearButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            doneButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    @objc private func clearCanvas() {
        canvasView.clear()
    }

    @objc private func cancel() {
        dismiss(nil)
    }

    @objc private func done() {
        guard let image = canvasView.captureImage() else {
            dismiss(nil)
            return
        }
        onCapture?(image)
        dismiss(nil)
    }
}

// MARK: - SignatureCanvasView

final class SignatureCanvasView: NSView {
    private var paths: [(path: NSBezierPath, color: NSColor, width: CGFloat)] = []
    private var currentPath: NSBezierPath?

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = 2.5
        path.move(to: pt)
        currentPath = path
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentPath?.line(to: pt)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let path = currentPath {
            paths.append((path: path, color: .black, width: 2.5))
            currentPath = nil
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        for item in paths {
            item.color.setStroke()
            item.path.lineWidth = item.width
            item.path.stroke()
        }
        currentPath?.stroke()
    }

    func clear() {
        paths = []
        currentPath = nil
        needsDisplay = true
    }

    func captureImage() -> NSImage? {
        guard !paths.isEmpty else { return nil }
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        // Transparent background — do NOT fill white
        for item in paths {
            item.color.setStroke()
            item.path.lineWidth = item.width
            item.path.stroke()
        }
        image.unlockFocus()
        return image
    }

    override var isOpaque: Bool { true }
}
