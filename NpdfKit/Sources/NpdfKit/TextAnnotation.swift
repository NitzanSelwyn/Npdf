import Foundation
import PDFKit
import AppKit

/// Builds FreeText PDFAnnotation objects.
public final class TextAnnotationBuilder {
    public init() {}

    public func makeAnnotation(
        text: String,
        at origin: CGPoint,
        size: CGSize = CGSize(width: 200, height: 40),
        font: NSFont = .systemFont(ofSize: 14),
        color: NSColor = .black,
        backgroundColor: NSColor = .clear
    ) -> PDFAnnotation {
        let bounds = CGRect(origin: origin, size: size)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = font
        annotation.fontColor = color
        annotation.color = backgroundColor
        annotation.isReadOnly = false
        return annotation
    }
}
