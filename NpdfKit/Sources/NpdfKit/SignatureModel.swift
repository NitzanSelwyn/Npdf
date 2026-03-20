import Foundation

public struct SignatureModel: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var imagePath: String   // relative to signatures directory
    public var isDefault: Bool

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), imagePath: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.imagePath = imagePath
        self.isDefault = isDefault
    }
}
