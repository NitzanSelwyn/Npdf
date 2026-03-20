import AppKit
import PDFKit

/// PDFAnnotation subclass for freehand ink strokes.
/// Stores paths in PDF page coordinates and draws them via Core Graphics,
/// which PDFKit uses both for on-screen rendering and when generating the PDF appearance stream on save.
final class NpdfInkAnnotation: PDFAnnotation {
    var inkPaths: [NSBezierPath] = []

    init(paths: [NSBezierPath], color: NSColor, lineWidth: CGFloat) {
        var boundingRect = CGRect.null
        for path in paths { boundingRect = boundingRect.union(path.bounds) }
        let padding = lineWidth * 2
        if boundingRect.isNull { boundingRect = .zero }
        boundingRect = boundingRect.insetBy(dx: -padding, dy: -padding)

        super.init(bounds: boundingRect, forType: .ink, withProperties: nil)
        self.inkPaths = paths
        self.color = color
        let border = PDFBorder()
        border.lineWidth = lineWidth
        self.border = border
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.saveGState()
        let strokeColor = (color as NSColor?)?.cgColor ?? CGColor(red: 0, green: 0.4, blue: 1, alpha: 1)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(border?.lineWidth ?? 2)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for path in inkPaths {
            // Convert NSBezierPath → CGPath compatible with macOS 13
            let cgPath = CGMutablePath()
            var points = [NSPoint](repeating: .zero, count: 3)
            for i in 0..<path.elementCount {
                let type = path.element(at: i, associatedPoints: &points)
                switch type {
                case .moveTo:  cgPath.move(to: points[0])
                case .lineTo:  cgPath.addLine(to: points[0])
                case .curveTo: cgPath.addCurve(to: points[2], control1: points[0], control2: points[1])
                case .closePath: cgPath.closeSubpath()
                @unknown default: break
                }
            }
            context.addPath(cgPath)
            context.strokePath()
        }
        context.restoreGState()
    }
}

/// PDFAnnotation subclass for signature images.
/// Renders an NSImage into the annotation bounds via Core Graphics.
final class NpdfSignatureAnnotation: PDFAnnotation {
    var signatureNSImage: NSImage?

    init(image: NSImage, bounds: CGRect) {
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        self.signatureNSImage = image
        self.color = .clear
        self.stampName = "Signature"
        self.contents = "Signature"
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let image = signatureNSImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }
        context.saveGState()
        // Draw with source-over so transparency in the PNG is preserved
        context.setBlendMode(.normal)
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}
