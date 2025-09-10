import Foundation

struct Asset: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: AssetType
    
    init(name: String, type: AssetType) {
        self.name = name
        self.type = type
    }
}

enum AssetType: String, CaseIterable, Codable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case document = "Document"
    case archive = "Archive"
    case other = "Other"
    
    var systemImage: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .document:
            return "doc"
        case .archive:
            return "archivebox"
        case .other:
            return "questionmark.circle"
        }
    }
}