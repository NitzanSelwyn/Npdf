import Foundation
import AppKit
import NpdfKit

enum ToolMode: Equatable {
    case select
    case ink
    case text
    case stamp(StampSymbol)
    case signature
    case eraser
    case highlight
}
