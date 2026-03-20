import Foundation
import AppKit
import Combine

final class ToolSettings: ObservableObject {
    @Published var currentTool: ToolMode = .ink {
        didSet { npdfLog("[TOOL] switched to \(currentTool)", .tool) }
    }
    @Published var color: NSColor = .systemBlue {
        didSet { npdfLog("[TOOL] color changed to \(color.description)", .tool) }
    }
    @Published var strokeWidth: CGFloat = 3.0 {
        didSet { npdfLog("[TOOL] strokeWidth changed to \(strokeWidth)", .tool) }
    }
    @Published var opacity: CGFloat = 1.0
    @Published var fontSize: CGFloat = 14.0 {
        didSet { npdfLog("[TOOL] fontSize changed to \(fontSize)", .tool) }
    }
    @Published var isBold: Bool = false {
        didSet { npdfLog("[TOOL] bold = \(isBold)", .tool) }
    }
    @Published var isItalic: Bool = false {
        didSet { npdfLog("[TOOL] italic = \(isItalic)", .tool) }
    }

    var currentFont: NSFont {
        var traits: NSFontTraitMask = []
        if isBold   { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }
        let base = NSFont.systemFont(ofSize: fontSize)
        return NSFontManager.shared.font(withFamily: base.familyName ?? "Helvetica",
                                         traits: traits,
                                         weight: isBold ? 9 : 5,
                                         size: fontSize) ?? base
    }
}
