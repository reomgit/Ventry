import Foundation

struct Collection: Identifiable, Codable {
    let id: UUID
    let name: String
    var path: String  // Source directory path
    var assets: [Asset]
    var lastScanned: Date  // Track when collection was last refreshed
    let version: Int  // For future schema changes

    init(name: String, path: String, assets: [Asset] = []) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.assets = assets
        self.lastScanned = Date()
        self.version = 1
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, assets, lastScanned, version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.assets = try container.decodeIfPresent([Asset].self, forKey: .assets) ?? []
        self.lastScanned = try container.decodeIfPresent(Date.self, forKey: .lastScanned) ?? Date()
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(assets, forKey: .assets)
        try container.encode(lastScanned, forKey: .lastScanned)
        try container.encode(version, forKey: .version)
    }

    var assetCount: Int {
        assets.count
    }

    mutating func addAsset(_ asset: Asset) {
        assets.append(asset)
    }

    mutating func removeAsset(withId id: UUID) {
        assets.removeAll { $0.id == id }
    }

    // Update assets after rescanning
    mutating func updateAssets(_ newAssets: [Asset]) {
        self.assets = newAssets
        self.lastScanned = Date()
    }
}
