import AppKit

/// A floating text editor that appears over the PDF page when the text tool is active.
/// Presents an NSTextView at the click location; commits on Return or click-outside, cancels on Escape.
final class TextEditorOverlayView: NSView {
    var onCommit: ((String, CGSize) -> Void)?
    var onCancel: (() -> Void)?

    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    private var minWidth: CGFloat = 120
    private var minHeight: CGFloat = 28

    // MARK: - Init

    init(at origin: CGPoint,
         initialText: String = "",
         font: NSFont = .systemFont(ofSize: 14),
         textColor: NSColor = .black) {
        let initialFrame = CGRect(x: origin.x, y: origin.y, width: 160, height: 36)
        super.init(frame: initialFrame)
        setup(initialText: initialText, font: font, textColor: textColor)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(initialText: String, font: NSFont, textColor: NSColor) {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 1.5
        layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.95).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.15
        layer?.shadowRadius = 4
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        // NSTextView inside a scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = font
        textView.textColor = textColor
        textView.string = initialText
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.delegate = self

        scrollView.documentView = textView
        textView.frame = scrollView.bounds

        // Select all initial text so user can overwrite
        if !initialText.isEmpty {
            textView.selectAll(nil)
        }
    }

    // MARK: - Focus

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return window?.makeFirstResponder(textView) ?? false
    }

    // MARK: - Key handling

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
            return
        }
        // Return commits; Shift+Return inserts a newline
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            commit()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Mouse outside

    override func mouseDown(with event: NSEvent) {
        // Clicks inside the editor are handled by NSTextView — this should not fire for inside clicks
        super.mouseDown(with: event)
    }

    // MARK: - Commit/Cancel

    func commit() {
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            onCancel?()
            return
        }
        let contentSize = textView.layoutManager.map { lm -> CGSize in
            lm.ensureLayout(for: textView.textContainer!)
            let rect = lm.usedRect(for: textView.textContainer!)
            return CGSize(width: max(minWidth, rect.width + 16), height: max(minHeight, rect.height + 12))
        } ?? CGSize(width: frame.width, height: frame.height)
        onCommit?(text, contentSize)
    }

    // MARK: - Auto-resize as user types

    private func resizeToFit() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let newWidth = max(minWidth, usedRect.width + 20)
        let newHeight = max(minHeight, usedRect.height + 12)
        var newFrame = frame
        newFrame.size = CGSize(width: newWidth, height: newHeight)
        frame = newFrame
        textView.frame = scrollView.bounds
    }
}

// MARK: - NSTextViewDelegate

extension TextEditorOverlayView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        resizeToFit()
    }
}
