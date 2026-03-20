import Foundation
import PDFKit

/// Converts between PDF coordinate space (bottom-left origin) and view coordinate space (top-left origin).
public final class CoordinateConverter {
    public init() {}

    /// Convert a point in the PDFView's coordinate system to PDF page coordinates.
    public func pdfPoint(from viewPoint: CGPoint, in pdfView: PDFView, page: PDFPage) -> CGPoint {
        return pdfView.convert(viewPoint, to: page)
    }

    /// Convert a point in PDF page coordinates to the PDFView's coordinate system.
    public func viewPoint(from pdfPoint: CGPoint, in pdfView: PDFView, page: PDFPage) -> CGPoint {
        return pdfView.convert(pdfPoint, from: page)
    }

    /// Convert a rect in the PDFView's coordinate system to PDF page coordinates.
    public func pdfRect(from viewRect: CGRect, in pdfView: PDFView, page: PDFPage) -> CGRect {
        return pdfView.convert(viewRect, to: page)
    }

    /// Convert a rect in PDF page coordinates to the PDFView's coordinate system.
    public func viewRect(from pdfRect: CGRect, in pdfView: PDFView, page: PDFPage) -> CGRect {
        return pdfView.convert(pdfRect, from: page)
    }

    /// Convert a path in the PDFView's coordinate system to an array of bezier paths in PDF page coordinates.
    public func pdfPath(from viewPath: CGPath, in pdfView: PDFView, page: PDFPage) -> CGPath {
        // Build transform: view → page coordinate space
        // PDFView.convert handles the bottom-left/top-left flip internally.
        var points: [CGPoint] = []
        viewPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            default:
                break
            }
        }
        guard !points.isEmpty else { return viewPath }

        let convertedPoints = points.map { pdfView.convert($0, to: page) }
        let mutablePath = CGMutablePath()
        mutablePath.move(to: convertedPoints[0])
        for pt in convertedPoints.dropFirst() {
            mutablePath.addLine(to: pt)
        }
        return mutablePath
    }
}
