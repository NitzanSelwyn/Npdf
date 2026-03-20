import AppKit
import NpdfKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        npdfLog("Application launched — log file: \(NpdfLogger.logFilePath)")
        if NSDocumentController.shared.documents.isEmpty {
            showOpenPanel()
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        showOpenPanel()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showOpenPanel()
        }
        return true
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.pdf]
        panel.title = "Open PDF"
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                npdfLog("Open panel cancelled", .document)
                return
            }
            npdfLog("Opening PDF: \(url.lastPathComponent)", .document)
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
    }
}
