import AppKit
import PDFKit
import NpdfKit

/// PDFAnnotation subclass for stamp symbols (checkmark, X, dot, circle, arrow).
/// Draws via Core Graphics in draw(with:in:) so PDFKit never falls back to text/emoji rendering.
final class NpdfStampAnnotation: PDFAnnotation {
    let symbol: StampSymbol

    init(symbol: StampSymbol, bounds: CGRect, color: NSColor) {
        self.symbol = symbol
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        self.color = color
        self.contents = symbol.rawValue   // stored for serialization / AnnotationSerializer
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.saveGState()
        StampAnnotationBuilder.render(
            symbol: symbol,
            in: bounds,
            color: (color as NSColor?)?.cgColor ?? CGColor(red: 0, green: 0.5, blue: 0, alpha: 1),
            context: context
        )
        context.restoreGState()
    }
}
