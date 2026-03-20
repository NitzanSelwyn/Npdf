import Foundation

/// Lightweight file logger. Writes timestamped entries to ~/Library/Logs/Npdf/npdf.log.
/// All writes are dispatched to a background serial queue to keep the main thread free.
final class NpdfLogger {
    static let shared = NpdfLogger()

    enum Category: String {
        case app        = "APP"
        case document   = "DOC"
        case tool       = "TOOL"
        case annotation = "ANNOTATION"
        case signature  = "SIGNATURE"
        case ui         = "UI"
        case error      = "ERROR"
    }

    private let queue = DispatchQueue(label: "com.npdf.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {
        queue.async { self.setupFile() }
    }

    private func setupFile() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Npdf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("npdf.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: url)
        fileHandle?.seekToEndOfFile()
        // Write a session separator
        let sep = "\n" + String(repeating: "─", count: 60) + "\n"
            + "  SESSION STARTED: \(dateFormatter.string(from: Date()))\n"
            + String(repeating: "─", count: 60) + "\n\n"
        write(sep)
    }

    func log(_ message: String, category: Category = .app) {
        queue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(category.rawValue)] \(message)\n"
            self.write(line)
        }
    }

    private func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        fileHandle?.write(data)
    }

    /// Returns the path to the current log file (for display / opening in Console.app).
    static var logFilePath: String {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Npdf")
        return dir.appendingPathComponent("npdf.log").path
    }
}

/// Convenience global function so call sites stay terse.
func npdfLog(_ message: String, _ category: NpdfLogger.Category = .app) {
    NpdfLogger.shared.log(message, category: category)
}
