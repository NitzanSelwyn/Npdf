import Foundation
import PDFKit

public enum PDFLoaderError: Error, LocalizedError {
    case fileNotFound
    case passwordRequired
    case wrongPassword
    case corruptFile
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound: return "The PDF file could not be found."
        case .passwordRequired: return "This PDF is password-protected."
        case .wrongPassword: return "Incorrect password."
        case .corruptFile: return "The PDF file appears to be corrupted."
        case .saveFailed(let e): return "Save failed: \(e.localizedDescription)"
        }
    }
}

public final class PDFLoader {
    public init() {}

    /// Load a PDFDocument asynchronously off the main thread.
    public func load(url: URL, password: String? = nil) async throws -> PDFDocument {
        return try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url) else {
                throw PDFLoaderError.corruptFile
            }
            if document.isLocked {
                guard let pwd = password else { throw PDFLoaderError.passwordRequired }
                guard document.unlock(withPassword: pwd) else { throw PDFLoaderError.wrongPassword }
            }
            return document
        }.value
    }

    /// Save a PDFDocument asynchronously off the main thread.
    public func save(_ document: PDFDocument, to url: URL) async throws {
        let success = try await Task.detached(priority: .userInitiated) {
            document.write(to: url)
        }.value
        if !success {
            throw PDFLoaderError.saveFailed(
                NSError(domain: "PDFLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDFDocument.write returned false"])
            )
        }
    }
}
