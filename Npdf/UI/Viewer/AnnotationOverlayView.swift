import AppKit
import PDFKit
import CoreGraphics
import NpdfKit

/// Transparent overlay drawn on top of each PDF page via pageOverlayViewProvider.
/// The overlay view's local coordinate system matches the page's view-space coordinates.
/// All conversions: overlay-local → PDFView → PDF-page.
final class AnnotationOverlayView: NSView {
    weak var pdfView: PDFView?
    weak var page: PDFPage?
    var toolSettings: ToolSettings?
    var annotationManager: AnnotationManager?
    var pendingSignatureImage: NSImage?

    // Drawing state
    private var currentPoints: [NSPoint] = []
    private let drawingLayer = CAShapeLayer()

    // Text editing state
    private var activeTextEditor: TextEditorOverlayView?
    private var editingExistingAnnotation: PDFAnnotation?

    // Selection state
    private var selectedAnnotation: PDFAnnotation?
    private var selectionView: SelectionHandleView?
    private var dragStartPoint: NSPoint = .zero
    private var dragOriginalBounds: CGRect = .zero
    private var lastMouseDownTime: TimeInterval = 0

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        drawingLayer.fillColor = NSColor.clear.cgColor
        drawingLayer.lineCap = .round
        drawingLayer.lineJoin = .round
        layer?.addSublayer(drawingLayer)
    }

    // MARK: - Coordinate conversion
    // The overlay view lives inside PDFView's page view hierarchy.
    // pdfView.convert(_, to: page) expects PDFView-space coordinates,
    // so we must first convert from our local space to PDFView space.

    private func toPDFPageCoords(_ localPoint: NSPoint) -> NSPoint {
        guard let pdfView, let page else { return localPoint }
        let inPDFViewSpace = convert(localPoint, to: pdfView)
        return pdfView.convert(inPDFViewSpace, to: page)
    }

    private func toOverlayCoords(_ pdfPoint: NSPoint) -> NSPoint {
        guard let pdfView, let page else { return pdfPoint }
        let inPDFViewSpace = pdfView.convert(pdfPoint, from: page)
        return convert(inPDFViewSpace, from: pdfView)
    }

    private func toOverlayRect(_ pdfRect: CGRect) -> CGRect {
        guard let pdfView, let page else { return pdfRect }
        let inPDFViewSpace = pdfView.convert(pdfRect, from: page)
        return convert(inPDFViewSpace, from: pdfView)
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        guard let tool = toolSettings?.currentTool else { return }
        switch tool {
        case .ink, .highlight, .text, .stamp, .signature:
            addCursorRect(bounds, cursor: .crosshair)
        case .eraser:
            addCursorRect(bounds, cursor: .disappearingItem)
        case .select:
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard let tool = toolSettings?.currentTool else { return }
        let localPoint = convert(event.locationInWindow, from: nil)

        // Any non-text tool click dismisses an open text editor
        if tool != .text { dismissActiveTextEditor(commit: true) }

        switch tool {
        case .ink, .highlight:
            npdfLog("[\(tool == .highlight ? "HIGHLIGHT" : "INK")] stroke started at \(localPoint)", .tool)
            currentPoints = [localPoint]
            updateDrawingLayer(with: currentPoints)

        case .select:
            handleSelectDown(at: localPoint)

        case .eraser:
            npdfLog("[ERASER] erase at \(localPoint)", .tool)
            eraseAnnotation(at: localPoint)

        case .text:
            npdfLog("[TEXT] place text at \(localPoint)", .tool)
            placeFreeTextAnnotation(at: localPoint)

        case .stamp(let symbol):
            npdfLog("[STAMP] place \(symbol.rawValue) at \(localPoint)", .tool)
            placeStampAnnotation(symbol: symbol, at: localPoint)

        case .signature:
            if let img = pendingSignatureImage {
                npdfLog("[SIGNATURE] place signature at \(localPoint)", .tool)
                placeSignatureAnnotation(image: img, at: localPoint)
            } else {
                npdfLog("[SIGNATURE] tap but no pending image", .tool)
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let tool = toolSettings?.currentTool else { return }
        let localPoint = convert(event.locationInWindow, from: nil)

        switch tool {
        case .ink, .highlight:
            currentPoints.append(localPoint)
            updateDrawingLayer(with: currentPoints)

        case .select:
            handleSelectDrag(to: localPoint)

        case .eraser:
            eraseAnnotation(at: localPoint)

        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let tool = toolSettings?.currentTool else { return }

        switch tool {
        case .ink, .highlight:
            commitInkStroke(isHighlight: tool == .highlight)
        case .select:
            handleSelectUp()
        default:
            break
        }
    }

    // MARK: - Ink drawing (real-time layer)

    private func updateDrawingLayer(with points: [NSPoint]) {
        guard points.count >= 1 else { return }
        let color = toolSettings?.color ?? .systemBlue
        let lineWidth = toolSettings?.strokeWidth ?? 3.0
        let opacity = Float(toolSettings?.opacity ?? 1.0)

        drawingLayer.strokeColor = color.cgColor
        drawingLayer.lineWidth = lineWidth
        drawingLayer.opacity = opacity

        let path = CGMutablePath()
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        drawingLayer.path = path
    }

    private func commitInkStroke(isHighlight: Bool) {
        defer {
            currentPoints = []
            drawingLayer.path = nil
        }
        guard currentPoints.count >= 2,
              let page, let annotationManager else {
            npdfLog("[\(isHighlight ? "HIGHLIGHT" : "INK")] stroke too short — discarded", .tool)
            return
        }
        npdfLog("[\(isHighlight ? "HIGHLIGHT" : "INK")] stroke committed with \(currentPoints.count) points", .annotation)

        let color = toolSettings?.color ?? .systemBlue
        let lineWidth = toolSettings?.strokeWidth ?? 3.0

        // Convert overlay-local coords → PDF page coords
        let pdfPoints = currentPoints.map { toPDFPageCoords($0) }

        if isHighlight {
            let xs = pdfPoints.map { $0.x }
            let ys = pdfPoints.map { $0.y }
            let rect = CGRect(
                x: xs.min()!, y: ys.min()!,
                width: max(1, xs.max()! - xs.min()!),
                height: max(lineWidth * 4, ys.max()! - ys.min()!)
            )
            let annotation = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
            annotation.color = color.withAlphaComponent(0.4)
            annotationManager.addAnnotation(annotation, to: page)
        } else {
            // Build NSBezierPath in PDF page coordinate space
            let bezier = NSBezierPath()
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round
            bezier.move(to: pdfPoints[0])
            for pt in pdfPoints.dropFirst() { bezier.line(to: pt) }

            let annotation = NpdfInkAnnotation(paths: [bezier], color: color, lineWidth: lineWidth)
            annotationManager.addAnnotation(annotation, to: page)
        }
    }

    // MARK: - Stamps

    private func placeStampAnnotation(symbol: StampSymbol, at localPoint: NSPoint) {
        guard let page, let annotationManager else { return }
        let color = toolSettings?.color ?? .systemBlue
        let size = toolSettings?.strokeWidth ?? 3.0
        let stampSize = max(24, size * 8)
        let pdfPoint = toPDFPageCoords(localPoint)

        let bounds = CGRect(
            x: pdfPoint.x - stampSize / 2,
            y: pdfPoint.y - stampSize / 2,
            width: stampSize,
            height: stampSize
        )
        let annotation = NpdfStampAnnotation(symbol: symbol, bounds: bounds, color: color)
        annotationManager.addAnnotation(annotation, to: page)
    }

    // MARK: - FreeText (inline editor)

    private func placeFreeTextAnnotation(at localPoint: NSPoint) {
        dismissActiveTextEditor(commit: true)
        showTextEditor(at: localPoint, existingAnnotation: nil)
    }

    private func showTextEditor(at localPoint: NSPoint, existingAnnotation: PDFAnnotation?) {
        let font = toolSettings?.currentFont ?? .systemFont(ofSize: 14)
        let color = toolSettings?.color ?? .black

        // Position the editor so its top-left is at the click point
        // NSView y-axis: 0 at bottom, so "top-left" means we offset downward by editor height
        let editorOrigin = CGPoint(x: localPoint.x, y: localPoint.y - 36)
        let editor = TextEditorOverlayView(
            at: editorOrigin,
            initialText: existingAnnotation?.contents ?? "",
            font: font,
            textColor: color
        )

        editor.onCommit = { [weak self, weak existingAnnotation] text, contentSize in
            self?.commitTextEditor(
                text: text,
                contentSize: contentSize,
                localOrigin: localPoint,
                existingAnnotation: existingAnnotation
            )
        }
        editor.onCancel = { [weak self] in
            self?.dismissActiveTextEditor(commit: false)
        }

        addSubview(editor)
        activeTextEditor = editor
        editingExistingAnnotation = existingAnnotation
        window?.makeFirstResponder(editor)
    }

    private func commitTextEditor(text: String, contentSize: CGSize, localOrigin: NSPoint, existingAnnotation: PDFAnnotation?) {
        defer { dismissActiveTextEditor(commit: false) }
        guard let page, let annotationManager else { return }
        if let _ = existingAnnotation {
            npdfLog("[TEXT] edited existing FreeText: \"\(text.prefix(60))\"", .annotation)
        } else {
            npdfLog("[TEXT] committed new FreeText at \(localOrigin): \"\(text.prefix(60))\"", .annotation)
        }

        let font = toolSettings?.currentFont ?? .systemFont(ofSize: 14)
        let color = toolSettings?.color ?? .black
        let pdfOrigin = toPDFPageCoords(localOrigin)

        // Scale content size from view-space to PDF-space
        let scaleFactor = pdfView?.scaleFactor ?? 1.0
        let pdfSize = CGSize(width: contentSize.width / scaleFactor,
                             height: contentSize.height / scaleFactor)

        if let existing = existingAnnotation {
            // Update existing annotation
            existing.contents = text
            existing.font = font
            existing.fontColor = color
            var newBounds = existing.bounds
            newBounds.size = pdfSize
            existing.bounds = newBounds
            annotationManager.undoManager?.setActionName("Edit Text")
        } else {
            let builder = TextAnnotationBuilder()
            let annotation = builder.makeAnnotation(
                text: text,
                at: pdfOrigin,
                size: pdfSize,
                font: font,
                color: color
            )
            annotationManager.addAnnotation(annotation, to: page)
        }
    }

    private func dismissActiveTextEditor(commit: Bool) {
        guard let editor = activeTextEditor else { return }
        if commit { editor.commit() }
        editor.removeFromSuperview()
        activeTextEditor = nil
        editingExistingAnnotation = nil
    }

    // MARK: - Signature

    private func placeSignatureAnnotation(image: NSImage, at localPoint: NSPoint) {
        guard let page, let annotationManager else { return }
        let pdfPoint = toPDFPageCoords(localPoint)
        let aspectRatio = image.size.width / max(1, image.size.height)
        let sigHeight: CGFloat = 60
        let sigWidth = sigHeight * aspectRatio
        let bounds = CGRect(
            x: pdfPoint.x - sigWidth / 2,
            y: pdfPoint.y - sigHeight / 2,
            width: sigWidth,
            height: sigHeight
        )
        let annotation = NpdfSignatureAnnotation(image: image, bounds: bounds)
        annotationManager.addAnnotation(annotation, to: page)
        pendingSignatureImage = nil

        // Auto-switch to select so the user can drag the signature immediately
        toolSettings?.currentTool = .select
        clearSelection()
        selectedAnnotation = annotation
        dragStartPoint = localPoint
        dragOriginalBounds = bounds
        showSelectionHandles(for: annotation)
    }

    // MARK: - Eraser

    private func eraseAnnotation(at localPoint: NSPoint) {
        guard let page, let annotationManager else { return }
        let pdfPoint = toPDFPageCoords(localPoint)

        // 1. PDFKit's own hit-test (works reliably for standard annotation types)
        if let hit = page.annotation(at: pdfPoint) {
            npdfLog("[ERASER] removed \(hit.type ?? "unknown") (PDFKit hit-test)", .annotation)
            annotationManager.removeAnnotation(hit, from: page)
            return
        }

        // 2. Fallback: expanded 8pt radius intersect search.
        //    Needed for custom subclasses and thin ink strokes where the
        //    bounding-box hit is too precise.
        let r: CGFloat = 8
        let hitRect = CGRect(x: pdfPoint.x - r, y: pdfPoint.y - r, width: r * 2, height: r * 2)
        if let hit = page.annotations.reversed().first(where: { $0.bounds.intersects(hitRect) }) {
            npdfLog("[ERASER] removed \(hit.type ?? "unknown") (bounds fallback hit-test)", .annotation)
            annotationManager.removeAnnotation(hit, from: page)
        } else {
            npdfLog("[ERASER] no annotation found at \(localPoint)", .tool)
        }
    }

    // MARK: - Selection

    private func handleSelectDown(at localPoint: NSPoint) {
        // Detect double-click
        let now = Date().timeIntervalSinceReferenceDate
        let isDoubleClick = (now - lastMouseDownTime) < NSEvent.doubleClickInterval
        lastMouseDownTime = now

        clearSelection()
        guard let page else { return }

        let annotation = annotationAt(localPoint)

        if let annotation {
            // Double-click on FreeText → edit inline
            if isDoubleClick, annotation.type == "FreeText" {
                npdfLog("[SELECT] double-click on FreeText — opening inline editor", .tool)
                showTextEditor(at: localPoint, existingAnnotation: annotation)
                return
            }
            npdfLog("[SELECT] selected \(annotation.type ?? "unknown") at \(localPoint)", .tool)
            selectedAnnotation = annotation
            dragStartPoint = localPoint
            dragOriginalBounds = annotation.bounds
            showSelectionHandles(for: annotation)
        } else {
            npdfLog("[SELECT] no annotation at \(localPoint) — cleared selection", .tool)
            dismissActiveTextEditor(commit: true)
        }
    }

    /// Two-pass annotation hit-test. PDFKit's annotation(at:) misses custom subclasses,
    /// so we fall back to a bounds search with a small hit radius.
    private func annotationAt(_ localPoint: NSPoint) -> PDFAnnotation? {
        guard let page else { return nil }
        let pdfPoint = toPDFPageCoords(localPoint)

        if let hit = page.annotation(at: pdfPoint) { return hit }

        let r: CGFloat = 6
        let hitRect = CGRect(x: pdfPoint.x - r, y: pdfPoint.y - r, width: r * 2, height: r * 2)
        return page.annotations.reversed().first { $0.bounds.intersects(hitRect) }
    }

    private func handleSelectDrag(to localPoint: NSPoint) {
        guard let annotation = selectedAnnotation, let pdfView else { return }
        // Delta in overlay-local space → scale by 1/scaleFactor to get PDF-space delta
        let delta = NSPoint(x: localPoint.x - dragStartPoint.x, y: localPoint.y - dragStartPoint.y)
        let pdfDelta = CGPoint(x: delta.x / pdfView.scaleFactor, y: delta.y / pdfView.scaleFactor)

        var newBounds = dragOriginalBounds
        newBounds.origin.x += pdfDelta.x
        newBounds.origin.y += pdfDelta.y
        annotation.bounds = newBounds
        updateSelectionHandles(for: annotation)
    }

    private func handleSelectUp() {
        guard let annotation = selectedAnnotation, let annotationManager else { return }
        let finalBounds = annotation.bounds
        let originalBounds = dragOriginalBounds
        if finalBounds != originalBounds {
            npdfLog("[SELECT] moved \(annotation.type ?? "unknown") from \(originalBounds.origin) to \(finalBounds.origin)", .annotation)
            annotationManager.undoManager?.registerUndo(withTarget: annotation) { ann in
                ann.bounds = originalBounds
            }
            annotationManager.undoManager?.setActionName("Move Annotation")
        }
    }

    private func showSelectionHandles(for annotation: PDFAnnotation) {
        let localRect = toOverlayRect(annotation.bounds)
        let handleView = SelectionHandleView(frame: localRect)

        handleView.onResize = { [weak self, weak annotation] newLocalRect in
            guard let self, let annotation else { return }
            annotation.bounds = self.toPDFPageRect(newLocalRect)
        }
        handleView.onResizeEnded = { [weak self, weak annotation] newLocalRect in
            guard let self, let annotation, let mgr = self.annotationManager else { return }
            let originalPDF = annotation.bounds  // already set by onResize
            let originalLocal = self.toOverlayRect(originalPDF)
            // originalBounds before drag started (stored in dragOriginalBounds)
            let beforePDF = self.dragOriginalBounds
            mgr.undoManager?.registerUndo(withTarget: annotation) { ann in
                ann.bounds = beforePDF
            }
            mgr.undoManager?.setActionName("Resize")
        }

        addSubview(handleView)
        selectionView = handleView
    }

    private func toPDFPageRect(_ localRect: CGRect) -> CGRect {
        guard let pdfView, let page else { return localRect }
        let inPDFViewSpace = convert(localRect, to: pdfView)
        return pdfView.convert(inPDFViewSpace, to: page)
    }

    private func updateSelectionHandles(for annotation: PDFAnnotation) {
        let localRect = toOverlayRect(annotation.bounds)
        selectionView?.frame = localRect
    }

    private func clearSelection() {
        selectionView?.removeFromSuperview()
        selectionView = nil
        selectedAnnotation = nil
    }
}

// MARK: - SelectionHandleView

final class SelectionHandleView: NSView {
    /// Called continuously during resize with the new frame in superview (overlay) coordinates.
    var onResize: ((CGRect) -> Void)?
    /// Called once on mouse-up after a resize drag.
    var onResizeEnded: ((CGRect) -> Void)?

    private enum Handle: CaseIterable {
        case bottomLeft, bottomCenter, bottomRight
        case middleLeft,               middleRight
        case topLeft,    topCenter,    topRight
    }

    private var activeHandle: Handle?
    private var resizeStartPointInSuperview: NSPoint = .zero
    private var resizeStartFrameInSuperview: CGRect  = .zero

    // MARK: - Hit testing

    private func handleCenter(_ h: Handle) -> CGPoint {
        switch h {
        case .bottomLeft:   return CGPoint(x: bounds.minX, y: bounds.minY)
        case .bottomCenter: return CGPoint(x: bounds.midX, y: bounds.minY)
        case .bottomRight:  return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .middleLeft:   return CGPoint(x: bounds.minX, y: bounds.midY)
        case .middleRight:  return CGPoint(x: bounds.maxX, y: bounds.midY)
        case .topLeft:      return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .topCenter:    return CGPoint(x: bounds.midX, y: bounds.maxY)
        case .topRight:     return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    private func handle(at localPoint: NSPoint) -> Handle? {
        let hitRadius: CGFloat = 8
        return Handle.allCases.first {
            let c = handleCenter($0)
            return abs(localPoint.x - c.x) <= hitRadius && abs(localPoint.y - c.y) <= hitRadius
        }
    }

    // MARK: - Resize math (all coords in superview space)

    private func apply(delta: CGPoint, handle: Handle, to start: CGRect) -> CGRect {
        var r = start
        switch handle {
        case .bottomLeft:
            r.origin.x += delta.x; r.size.width  -= delta.x
            r.origin.y += delta.y; r.size.height -= delta.y
        case .bottomCenter:
            r.origin.y += delta.y; r.size.height -= delta.y
        case .bottomRight:
            r.size.width  += delta.x
            r.origin.y += delta.y; r.size.height -= delta.y
        case .middleLeft:
            r.origin.x += delta.x; r.size.width  -= delta.x
        case .middleRight:
            r.size.width  += delta.x
        case .topLeft:
            r.origin.x += delta.x; r.size.width  -= delta.x
            r.size.height += delta.y
        case .topCenter:
            r.size.height += delta.y
        case .topRight:
            r.size.width  += delta.x
            r.size.height += delta.y
        }
        r.size.width  = max(20, r.size.width)
        r.size.height = max(20, r.size.height)
        return r
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if let h = handle(at: local) {
            // Start resize — record start position in superview space so frame changes don't shift coords
            activeHandle = h
            resizeStartPointInSuperview = superview?.convert(event.locationInWindow, from: nil) ?? local
            resizeStartFrameInSuperview = frame
        } else {
            // No handle hit → pass through to overlay view for move
            nextResponder?.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let h = activeHandle,
              let sv = superview else {
            nextResponder?.mouseDragged(with: event)
            return
        }
        let current = sv.convert(event.locationInWindow, from: nil)
        let delta   = CGPoint(x: current.x - resizeStartPointInSuperview.x,
                              y: current.y - resizeStartPointInSuperview.y)
        let newFrame = apply(delta: delta, handle: h, to: resizeStartFrameInSuperview)
        frame = newFrame          // visual update
        onResize?(newFrame)
    }

    override func mouseUp(with event: NSEvent) {
        if activeHandle != nil {
            onResizeEnded?(frame)
            activeHandle = nil
        } else {
            nextResponder?.mouseUp(with: event)
        }
    }

    // MARK: - Cursors

    override func resetCursorRects() {
        for h in Handle.allCases {
            let c = handleCenter(h)
            let r = CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)
            addCursorRect(r, cursor: cursor(for: h))
        }
    }

    private func cursor(for h: Handle) -> NSCursor {
        switch h {
        case .topLeft, .bottomRight:   return .init(image: NSCursor.resizeUpLeftDownRight, hotSpot: .zero)
        case .topRight, .bottomLeft:   return .init(image: NSCursor.resizeUpRightDownLeft, hotSpot: .zero)
        case .topCenter, .bottomCenter: return .resizeUpDown
        case .middleLeft, .middleRight: return .resizeLeftRight
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        bounds.fill()

        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1.5
        border.setLineDash([4, 3], count: 2, phase: 0)
        border.stroke()

        let handleSize: CGFloat = 8
        NSColor.white.setFill()
        NSColor.systemBlue.setStroke()
        for h in Handle.allCases {
            let c = handleCenter(h)
            let r = CGRect(x: c.x - handleSize / 2, y: c.y - handleSize / 2,
                           width: handleSize, height: handleSize)
            let circle = NSBezierPath(ovalIn: r)
            circle.fill()
            circle.lineWidth = 1.5
            circle.stroke()
        }
    }

    override var isOpaque: Bool { false }
}

// MARK: - Diagonal cursor helpers

private extension NSCursor {
    static var resizeUpLeftDownRight: NSImage {
        NSCursor.crosshair.image  // fallback; real diagonal cursors are private API
    }
    static var resizeUpRightDownLeft: NSImage {
        NSCursor.crosshair.image
    }
}
