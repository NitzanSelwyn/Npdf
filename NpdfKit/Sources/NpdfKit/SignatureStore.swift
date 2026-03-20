import Foundation
import AppKit

public enum SignatureStoreError: Error, LocalizedError {
    case directoryCreationFailed(Error)
    case imageEncodingFailed
    case writeFailed(Error)
    case deleteFailed(Error)
    case metadataLoadFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let e): return "Could not create signatures directory: \(e.localizedDescription)"
        case .imageEncodingFailed: return "Could not encode signature image as PNG."
        case .writeFailed(let e): return "Could not write signature: \(e.localizedDescription)"
        case .deleteFailed(let e): return "Could not delete signature: \(e.localizedDescription)"
        case .metadataLoadFailed(let e): return "Could not load signature metadata: \(e.localizedDescription)"
        }
    }
}

/// Persists signatures to ~/Library/Application Support/Npdf/signatures/
public final class SignatureStore {
    private let signaturesDirectory: URL
    private let metadataURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let npdfDir = appSupport.appendingPathComponent("Npdf", isDirectory: true)
        signaturesDirectory = npdfDir.appendingPathComponent("signatures", isDirectory: true)
        metadataURL = signaturesDirectory.appendingPathComponent("metadata.json")

        do {
            try FileManager.default.createDirectory(at: signaturesDirectory, withIntermediateDirectories: true)
        } catch {
            throw SignatureStoreError.directoryCreationFailed(error)
        }
    }

    // MARK: - CRUD

    public func save(_ image: NSImage, name: String, isDefault: Bool = false) throws -> SignatureModel {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SignatureStoreError.imageEncodingFailed
        }

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let imageURL = signaturesDirectory.appendingPathComponent(filename)

        do {
            try pngData.write(to: imageURL)
        } catch {
            throw SignatureStoreError.writeFailed(error)
        }

        var model = SignatureModel(id: id, name: name, imagePath: filename, isDefault: isDefault)

        var all = loadAll()
        if isDefault {
            for i in all.indices { all[i].isDefault = false }
        }
        all.append(model)
        try persistMetadata(all)

        return model
    }

    public func loadAll() -> [SignatureModel] {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return [] }
        guard let data = try? Data(contentsOf: metadataURL),
              let models = try? decoder.decode([SignatureModel].self, from: data) else {
            return []
        }
        return models
    }

    public func loadImage(for model: SignatureModel) -> NSImage? {
        let url = signaturesDirectory.appendingPathComponent(model.imagePath)
        return NSImage(contentsOf: url)
    }

    public func delete(_ id: UUID) throws {
        var all = loadAll()
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        let model = all[idx]
        let imageURL = signaturesDirectory.appendingPathComponent(model.imagePath)
        do {
            if FileManager.default.fileExists(atPath: imageURL.path) {
                try FileManager.default.removeItem(at: imageURL)
            }
        } catch {
            throw SignatureStoreError.deleteFailed(error)
        }
        all.remove(at: idx)
        try persistMetadata(all)
    }

    public func setDefault(_ id: UUID) throws {
        var all = loadAll()
        for i in all.indices { all[i].isDefault = all[i].id == id }
        try persistMetadata(all)
    }

    // MARK: - Private

    private func persistMetadata(_ models: [SignatureModel]) throws {
        do {
            let data = try encoder.encode(models)
            try data.write(to: metadataURL)
        } catch {
            throw SignatureStoreError.writeFailed(error)
        }
    }
}
