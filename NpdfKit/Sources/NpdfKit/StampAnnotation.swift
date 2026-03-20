import Foundation
import PDFKit
import CoreGraphics
import AppKit

public enum StampSymbol: String, CaseIterable {
    case checkmark
    case x
    case dot
    case circle
    case arrow
}

/// Builds stamp-style PDFAnnotations using custom Core Graphics appearance streams.
public final class StampAnnotationBuilder {
    public init() {}

    public func makeAnnotation(
        symbol: StampSymbol,
        at center: CGPoint,
        size: CGFloat = 24,
        color: CGColor,
        page: PDFPage
    ) -> PDFAnnotation {
        let bounds = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        let annotation = PDFAnnotation(bounds: bounds, forType: .stamp, withProperties: nil)
        annotation.color = NSColor(cgColor: color) ?? .systemBlue

        // Draw custom appearance into the annotation
        // PDFKit will use the annotation's color; we set the stamp name for identification.
        annotation.stampName = symbol.rawValue

        // Store symbol identifier in the annotation's contents so we can re-render on load.
        annotation.contents = symbol.rawValue

        return annotation
    }

    /// Render a stamp symbol into a CGContext at the given rect.
    public static func render(symbol: StampSymbol, in rect: CGRect, color: CGColor, context: CGContext) {
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(rect.width * 0.12)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let inset = rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.15)

        switch symbol {
        case .checkmark:
            // ✓ shape
            let startX = inset.minX
            let midX = inset.minX + inset.width * 0.38
            let endX = inset.maxX
            let startY = inset.midY
            let midY = inset.minY
            let endY = inset.maxY
            context.beginPath()
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: midX, y: midY))
            context.addLine(to: CGPoint(x: endX, y: endY))
            context.strokePath()

        case .x:
            context.beginPath()
            context.move(to: CGPoint(x: inset.minX, y: inset.minY))
            context.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
            context.move(to: CGPoint(x: inset.maxX, y: inset.minY))
            context.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
            context.strokePath()

        case .dot:
            let radius = min(inset.width, inset.height) * 0.3
            let center = CGPoint(x: rect.midX, y: rect.midY)
            context.beginPath()
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.fillPath()

        case .circle:
            let radius = min(inset.width, inset.height) * 0.45
            let center = CGPoint(x: rect.midX, y: rect.midY)
            context.beginPath()
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()

        case .arrow:
            let tip = CGPoint(x: inset.maxX, y: rect.midY)
            let tail = CGPoint(x: inset.minX, y: rect.midY)
            let headLen = inset.width * 0.35
            let headAngle: CGFloat = .pi / 6
            context.beginPath()
            context.move(to: tail)
            context.addLine(to: tip)
            // Arrowhead
            context.move(to: tip)
            context.addLine(to: CGPoint(
                x: tip.x - headLen * cos(headAngle),
                y: tip.y - headLen * sin(headAngle)
            ))
            context.move(to: tip)
            context.addLine(to: CGPoint(
                x: tip.x - headLen * cos(headAngle),
                y: tip.y + headLen * sin(headAngle)
            ))
            context.strokePath()
        }
    }
}
