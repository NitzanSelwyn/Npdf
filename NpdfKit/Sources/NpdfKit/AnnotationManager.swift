import Foundation
import PDFKit
import os.log

private let annotLog = Logger(subsystem: "com.npdf", category: "AnnotationManager")

/// Central manager for all annotation operations. Integrates with NSUndoManager.
public final class AnnotationManager {
    public weak var undoManager: UndoManager?

    public init(undoManager: UndoManager? = nil) {
        self.undoManager = undoManager
    }

    // MARK: - Add

    public func addAnnotation(_ annotation: PDFAnnotation, to page: PDFPage) {
        let pageLabel = page.label ?? "?"
        annotLog.info("ADD \(annotation.type ?? "unknown") on page \(pageLabel) bounds=\(String(describing: annotation.bounds))")
        page.addAnnotation(annotation)
        registerUndo(for: annotation, on: page, action: .add)
    }

    // MARK: - Remove

    public func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        let pageLabel = page.label ?? "?"
        annotLog.info("REMOVE \(annotation.type ?? "unknown") from page \(pageLabel)")
        page.removeAnnotation(annotation)
        registerUndo(for: annotation, on: page, action: .remove)
    }

    // MARK: - Move

    public func moveAnnotation(_ annotation: PDFAnnotation, to newOrigin: CGPoint) {
        annotLog.info("MOVE \(annotation.type ?? "unknown") to \(String(describing: newOrigin))")
        let oldBounds = annotation.bounds
        var newBounds = oldBounds
        newBounds.origin = newOrigin
        annotation.bounds = newBounds
        undoManager?.registerUndo(withTarget: self) { [weak annotation] mgr in
            guard let annotation else { return }
            annotation.bounds = oldBounds
            mgr.undoManager?.setActionName("Move Annotation")
        }
        undoManager?.setActionName("Move Annotation")
    }

    // MARK: - Resize

    public func resizeAnnotation(_ annotation: PDFAnnotation, to newSize: CGSize) {
        annotLog.info("RESIZE \(annotation.type ?? "unknown") to \(String(describing: newSize))")
        let oldBounds = annotation.bounds
        var newBounds = oldBounds
        newBounds.size = newSize
        annotation.bounds = newBounds
        undoManager?.registerUndo(withTarget: self) { [weak annotation] mgr in
            guard let annotation else { return }
            annotation.bounds = oldBounds
            mgr.undoManager?.setActionName("Resize Annotation")
        }
        undoManager?.setActionName("Resize Annotation")
    }

    // MARK: - Private

    private enum UndoAction { case add, remove }

    private func registerUndo(for annotation: PDFAnnotation, on page: PDFPage, action: UndoAction) {
        switch action {
        case .add:
            undoManager?.registerUndo(withTarget: self) { [weak annotation, weak page] mgr in
                guard let annotation, let page else { return }
                page.removeAnnotation(annotation)
                mgr.registerUndo(for: annotation, on: page, action: .remove)
            }
            undoManager?.setActionName("Add Annotation")
        case .remove:
            undoManager?.registerUndo(withTarget: self) { [weak annotation, weak page] mgr in
                guard let annotation, let page else { return }
                page.addAnnotation(annotation)
                mgr.registerUndo(for: annotation, on: page, action: .add)
            }
            undoManager?.setActionName("Remove Annotation")
        }
    }
}
