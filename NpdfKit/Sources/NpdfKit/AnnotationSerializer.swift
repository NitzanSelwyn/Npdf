import Foundation
import PDFKit
import AppKit

/// Helpers to identify annotation types and extract metadata stored in toolTip/stampName.
public final class AnnotationSerializer {
    public init() {}

    public enum AnnotationType {
        case ink
        case stamp(StampSymbol)
        case freeText
        case signature
        case highlight
        case unknown
    }

    public func type(of annotation: PDFAnnotation) -> AnnotationType {
        switch annotation.type {
        case "Ink":
            return .ink
        case "Stamp":
            if let contents = annotation.contents, let symbol = StampSymbol(rawValue: contents) {
                return .stamp(symbol)
            }
            // Could be a signature stamp
            return .signature
        case "FreeText":
            return .freeText
        case "Highlight":
            return .highlight
        default:
            return .unknown
        }
    }
}
