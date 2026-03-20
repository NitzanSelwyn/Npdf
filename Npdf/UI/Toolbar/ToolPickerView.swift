import SwiftUI
import NpdfKit

struct ToolPickerView: View {
    @ObservedObject var toolSettings: ToolSettings

    var body: some View {
        HStack(spacing: 2) {
            toolButton(icon: "arrow.up.left.and.arrow.down.right", tool: .select, tooltip: "Select")
            toolButton(icon: "pencil", tool: .ink, tooltip: "Ink")
            toolButton(icon: "highlighter", tool: .highlight, tooltip: "Highlight")
            toolButton(icon: "textformat", tool: .text, tooltip: "Text")
            stampMenu()
            toolButton(icon: "signature", tool: .signature, tooltip: "Signature")
            toolButton(icon: "eraser", tool: .eraser, tooltip: "Eraser")
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func toolButton(icon: String, tool: ToolMode, tooltip: String) -> some View {
        Button(action: { toolSettings.currentTool = tool }) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .background(toolSettings.currentTool == tool
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    @ViewBuilder
    private func stampMenu() -> some View {
        Menu {
            ForEach(StampSymbol.allCases, id: \.self) { symbol in
                Button(action: { toolSettings.currentTool = .stamp(symbol) }) {
                    Label(symbol.label, systemImage: symbol.icon)
                }
            }
        } label: {
            Image(systemName: stampIcon)
                .frame(width: 28, height: 28)
                .background(isStampActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(5)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 32)
        .help("Stamps")
    }

    private var isStampActive: Bool {
        if case .stamp = toolSettings.currentTool { return true }
        return false
    }

    private var stampIcon: String {
        if case .stamp(let sym) = toolSettings.currentTool { return sym.icon }
        return "checkmark.circle"
    }
}

// MARK: - ColorPickerButton (NSColorWell wrapped — renders as a small swatch, not a pill)

struct ColorPickerButton: NSViewRepresentable {
    @ObservedObject var toolSettings: ToolSettings

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(style: .minimal)
        well.color = toolSettings.color
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        well.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            well.widthAnchor.constraint(equalToConstant: 28),
            well.heightAnchor.constraint(equalToConstant: 28),
        ])
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        nsView.color = toolSettings.color
    }

    func makeCoordinator() -> Coordinator { Coordinator(toolSettings: toolSettings) }

    final class Coordinator: NSObject {
        let toolSettings: ToolSettings
        init(toolSettings: ToolSettings) { self.toolSettings = toolSettings }
        @objc func colorChanged(_ sender: NSColorWell) {
            toolSettings.color = sender.color
        }
    }
}

// MARK: - SizeSliderView

struct SizeSliderView: View {
    @ObservedObject var toolSettings: ToolSettings

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "line.diagonal")
                .imageScale(.small)
                .foregroundColor(.secondary)
            Slider(value: $toolSettings.strokeWidth, in: 1...20, step: 0.5)
                .frame(width: 80)
        }
    }
}

// MARK: - TextFormattingView (shown when text tool is active)

struct TextFormattingView: View {
    @ObservedObject var toolSettings: ToolSettings

    var body: some View {
        HStack(spacing: 4) {
            // Font size stepper
            HStack(spacing: 2) {
                Button(action: { toolSettings.fontSize = max(6, toolSettings.fontSize - 1) }) {
                    Image(systemName: "minus")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)

                Text("\(Int(toolSettings.fontSize))")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minWidth: 22, alignment: .center)

                Button(action: { toolSettings.fontSize = min(72, toolSettings.fontSize + 1) }) {
                    Image(systemName: "plus")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(5)

            // Bold
            Toggle(isOn: $toolSettings.isBold) {
                Text("B").bold().font(.system(size: 13))
            }
            .toggleStyle(.button)
            .frame(width: 26, height: 26)

            // Italic
            Toggle(isOn: $toolSettings.isItalic) {
                Text("I").italic().font(.system(size: 13))
            }
            .toggleStyle(.button)
            .frame(width: 26, height: 26)
        }
    }
}

// MARK: - StampSymbol helpers

import NpdfKit

extension StampSymbol {
    var icon: String {
        switch self {
        case .checkmark: return "checkmark"
        case .x:         return "xmark"
        case .dot:       return "circle.fill"
        case .circle:    return "circle"
        case .arrow:     return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .checkmark: return "Checkmark ✓"
        case .x:         return "X Mark ✗"
        case .dot:       return "Dot •"
        case .circle:    return "Circle ○"
        case .arrow:     return "Arrow →"
        }
    }
}
