import AppKit
import SwiftUI
import NpdfKit

final class ToolbarController: NSObject, NSToolbarDelegate {
    static let toolbarIdentifier = NSToolbar.Identifier("NpdfToolbar")

    enum ItemID {
        static let openFile   = NSToolbarItem.Identifier("openFile")
        static let save       = NSToolbarItem.Identifier("save")
        static let separator1 = NSToolbarItem.Identifier("sep1")
        static let toolPicker = NSToolbarItem.Identifier("toolPicker")
        static let colorPicker = NSToolbarItem.Identifier("colorPicker")
        static let sizeSlider  = NSToolbarItem.Identifier("sizeSlider")
        static let separator2 = NSToolbarItem.Identifier("sep2")
        static let undo       = NSToolbarItem.Identifier("undo")
        static let redo       = NSToolbarItem.Identifier("redo")
        static let separator3 = NSToolbarItem.Identifier("sep3")
        static let zoomOut    = NSToolbarItem.Identifier("zoomOut")
        static let zoomIn     = NSToolbarItem.Identifier("zoomIn")
        static let zoomActual      = NSToolbarItem.Identifier("zoomActual")
        static let signaturesPanel  = NSToolbarItem.Identifier("signaturesPanel")
        static let textFormatting   = NSToolbarItem.Identifier("textFormatting")
        static let openLogs         = NSToolbarItem.Identifier("openLogs")
        static let flexSpace       = NSToolbarItem.Identifier(NSToolbarItem.Identifier.flexibleSpace.rawValue)
    }

    weak var windowController: MainWindowController?
    private var toolSettings: ToolSettings

    init(toolSettings: ToolSettings) {
        self.toolSettings = toolSettings
        super.init()
    }

    func makeToolbar(for window: NSWindow) -> NSToolbar {
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        return toolbar
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ItemID.openFile, ItemID.save,
            .flexibleSpace,
            ItemID.toolPicker,
            .space,
            ItemID.colorPicker,
            ItemID.sizeSlider,
            .flexibleSpace,
            ItemID.undo, ItemID.redo,
            .space,
            ItemID.zoomOut, ItemID.zoomActual, ItemID.zoomIn,
            .space,
            ItemID.textFormatting,
            .flexibleSpace,
            ItemID.signaturesPanel,
            .space,
            ItemID.openLogs,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case ItemID.openFile:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Open"
            item.toolTip = "Open PDF (⌘O)"
            item.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Open")
            item.target = windowController
            item.action = #selector(MainWindowController.openDocument(_:))
            return item

        case ItemID.save:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Save"
            item.toolTip = "Save (⌘S)"
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")
            item.target = windowController
            item.action = #selector(MainWindowController.saveDocument(_:))
            return item

        case ItemID.toolPicker:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Tool"
            let hostingView = NSHostingView(rootView: ToolPickerView(toolSettings: toolSettings))
            hostingView.frame = CGRect(x: 0, y: 0, width: 300, height: 32)
            item.view = hostingView
            return item

        case ItemID.colorPicker:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Color"
            item.toolTip = "Stroke Color"
            // Use NSColorWell directly — NSHostingView<ColorPickerButton> renders it correctly
            let well = ColorWellToolbarView(toolSettings: toolSettings)
            well.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
            item.view = well
            item.minSize = CGSize(width: 32, height: 32)
            item.maxSize = CGSize(width: 32, height: 32)
            return item

        case ItemID.sizeSlider:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Size"
            let hostingView = NSHostingView(rootView: SizeSliderView(toolSettings: toolSettings))
            hostingView.frame = CGRect(x: 0, y: 0, width: 120, height: 32)
            item.view = hostingView
            return item

        case ItemID.undo:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Undo"
            item.toolTip = "Undo (⌘Z)"
            item.image = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: "Undo")
            item.target = nil  // First responder
            item.action = Selector(("undo:"))
            return item

        case ItemID.redo:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Redo"
            item.toolTip = "Redo (⌘⇧Z)"
            item.image = NSImage(systemSymbolName: "arrow.uturn.forward", accessibilityDescription: "Redo")
            item.target = nil
            item.action = Selector(("redo:"))
            return item

        case ItemID.zoomOut:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Zoom Out"
            item.toolTip = "Zoom Out (⌘-)"
            item.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out")
            item.target = windowController
            item.action = #selector(MainWindowController.zoomOut(_:))
            return item

        case ItemID.zoomIn:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Zoom In"
            item.toolTip = "Zoom In (⌘+)"
            item.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In")
            item.target = windowController
            item.action = #selector(MainWindowController.zoomIn(_:))
            return item

        case ItemID.zoomActual:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Actual Size"
            item.toolTip = "Actual Size (⌘0)"
            item.image = NSImage(systemSymbolName: "1.magnifyingglass", accessibilityDescription: "Actual Size")
            item.target = windowController
            item.action = #selector(MainWindowController.zoomActualSize(_:))
            return item

        case ItemID.textFormatting:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Text Format"
            item.toolTip = "Font size, bold, italic (active when Text tool is selected)"
            let hostingView = NSHostingView(rootView: TextFormattingView(toolSettings: toolSettings))
            hostingView.frame = CGRect(x: 0, y: 0, width: 130, height: 32)
            item.view = hostingView
            return item

        case ItemID.signaturesPanel:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Signatures"
            item.toolTip = "Show/Hide Signatures Panel"
            item.image = NSImage(systemSymbolName: "signature", accessibilityDescription: "Signatures")
            item.target = windowController
            item.action = #selector(MainWindowController.toggleSignaturePanel(_:))
            return item

        case ItemID.openLogs:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Logs"
            item.toolTip = "Open log file in Console"
            item.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Open Logs")
            item.target = windowController
            item.action = #selector(MainWindowController.openLogFile(_:))
            return item

        default:
            return nil
        }
    }
}

// MARK: - ColorWellToolbarView

/// A plain NSView that embeds an NSColorWell — avoids SwiftUI ColorPicker's oversized rendering.
final class ColorWellToolbarView: NSView {
    private let colorWell = NSColorWell(style: .minimal)
    private let toolSettings: ToolSettings

    init(toolSettings: ToolSettings) {
        self.toolSettings = toolSettings
        super.init(frame: CGRect(x: 0, y: 0, width: 32, height: 32))

        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.color = toolSettings.color
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        addSubview(colorWell)

        NSLayoutConstraint.activate([
            colorWell.centerXAnchor.constraint(equalTo: centerXAnchor),
            colorWell.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorWell.widthAnchor.constraint(equalToConstant: 28),
            colorWell.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Sync color well when toolSettings changes
        NotificationCenter.default.addObserver(
            self, selector: #selector(syncColor),
            name: .init("ToolSettingsColorChanged"), object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func colorChanged(_ sender: NSColorWell) {
        toolSettings.color = sender.color
    }

    @objc private func syncColor() {
        colorWell.color = toolSettings.color
    }
}
