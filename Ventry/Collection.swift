import Foundation

struct Collection: Identifiable, Codable {
    let id = UUID()
    let name: String
    var assets: [Asset]
    
    init(name: String, assets: [Asset] = []) {
        self.name = name
        self.assets = assets
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
}