import Foundation
import PDFKit
import CoreGraphics

/// Builds PDFAnnotation objects for freehand ink strokes.
public final class InkAnnotationBuilder {
    public init() {}

    /// Create a PDFAnnotation of subtype Ink from an array of bezier paths (in PDF page coordinates).
    /// - Parameters:
    ///   - paths: Array of CGPath in PDF page coordinate space.
    ///   - color: Stroke color.
    ///   - lineWidth: Stroke width.
    ///   - page: The target PDFPage (used for bounding-box calculation).
    public func makeAnnotation(
        paths: [CGPath],
        color: CGColor,
        lineWidth: CGFloat,
        page: PDFPage
    ) -> PDFAnnotation {
        // Compute bounding rect from all paths
        var boundingRect = CGRect.null
        for path in paths {
            boundingRect = boundingRect.union(path.boundingBoxOfPath)
        }
        // Add padding for stroke width
        let padding = lineWidth * 2
        boundingRect = boundingRect.insetBy(dx: -padding, dy: -padding)

        let annotation = PDFAnnotation(bounds: boundingRect, forType: .ink, withProperties: nil)
        annotation.color = NSColor(cgColor: color) ?? .systemBlue
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = lineWidth

        // Convert CGPaths to arrays of NSValue-wrapped CGPoints for PDFKit
        var allPaths: [[NSValue]] = []
        for path in paths {
            var points: [NSValue] = []
            path.applyWithBlock { element in
                let type = element.pointee.type
                if type == .moveToPoint || type == .addLineToPoint {
                    let pt = element.pointee.points[0]
                    points.append(NSValue(point: NSPoint(x: pt.x, y: pt.y)))
                }
            }
            if !points.isEmpty {
                allPaths.append(points)
            }
        }
        // PDFAnnotationInk paths must be set at init via setValue; PDFKit API exposes this
        // through the internal setter. We set the paths via KVC.
        let bezierPaths = allPaths.map { pointValues -> NSBezierPath in
            let bezier = NSBezierPath()
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round
            for (i, val) in pointValues.enumerated() {
                let pt = val.pointValue
                if i == 0 { bezier.move(to: pt) }
                else { bezier.line(to: pt) }
            }
            return bezier
        }
        annotation.setValue(bezierPaths, forAnnotationKey: PDFAnnotationKey(rawValue: "/InkList"))

        return annotation
    }
}
