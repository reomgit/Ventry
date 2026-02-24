import Foundation
import SwiftUI

// MARK: - Starred Items
struct StarredItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: StarredItemType
    let path: String?
    
    init(name: String, type: StarredItemType, path: String? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.path = path
    }
}

enum StarredItemType: String, CaseIterable, Codable {
    case folder = "Folder"
    case file = "File"
    case collection = "Collection"
    
    var systemImage: String {
        switch self {
        case .folder:
            return "folder.fill"
        case .file:
            return "doc.fill"
        case .collection:
            return "tray.fill"
        }
    }
}

// MARK: - Applications
struct Application: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let iconName: String?
    let bundlePath: String?
    var directories: [AppDirectory]

    init(name: String, bundleIdentifier: String, iconName: String? = nil, bundlePath: String? = nil, directories: [AppDirectory] = []) {
        self.id = UUID()
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.iconName = iconName
        self.bundlePath = bundlePath
        self.directories = directories
    }
    
    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.id == rhs.id
    }
    
    mutating func addDirectory(_ directory: AppDirectory) {
        directories.append(directory)
    }
    
    mutating func removeDirectory(withId id: UUID) {
        directories.removeAll { $0.id == id }
    }
}

struct AppDirectory: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: String
    var type: DirectoryType
    
    init(id: UUID = UUID(), name: String, path: String, type: DirectoryType) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
    }
}

enum DirectoryType: String, CaseIterable, Codable {
    case applications = "Applications"
    case effects = "Effects"
    case plugins = "Plugins"
    case presets = "Presets"
    case templates = "Templates"
    case scripts = "Scripts"
    case assets = "Assets"
    case other = "Other"
    
    var systemImage: String {
        switch self {
        case .applications:
            return "app"
        case .effects:
            return "wand.and.stars"
        case .plugins:
            return "puzzlepiece.extension"
        case .presets:
            return "slider.horizontal.3"
        case .templates:
            return "doc.richtext"
        case .scripts:
            return "scroll"
        case .assets:
            return "photo.stack"
        case .other:
            return "folder"
        }
    }
}

// MARK: - User Tags
struct UserTag: Identifiable, Codable {
    let id: UUID
    let name: String
    let color: TagColor
    var itemCount: Int
    
    init(name: String, color: TagColor, itemCount: Int = 0) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.itemCount = itemCount
    }
}

enum TagColor: String, CaseIterable, Codable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case gray = "Gray"
    
    var color: Color {
        switch self {
        case .red:
            return .red
        case .orange:
            return .orange
        case .yellow:
            return .yellow
        case .green:
            return .green
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .pink:
            return .pink
        case .gray:
            return .gray
        }
    }
}

// MARK: - Regular Folders
enum RegularFolder: String, CaseIterable {
    case fonts = "Fonts"
    case designAssets = "Design Assets"
    case downloads = "Downloads"

    var systemImage: String {
        switch self {
        case .fonts:
            return "textformat"
        case .designAssets:
            return "paintbrush"
        case .downloads:
            return "arrow.down.circle"
        }
    }

    var defaultPath: String {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        var homePath = homeURL.path

        // Ensure we're not using a container path
        if homePath.contains("/Library/Containers/") {
            print("⚠️ Warning: homeDirectoryForCurrentUser returned container path: \(homePath)")
            // Extract real user home from container path
            if let userMatch = homePath.range(of: #"/Users/[^/]+"#, options: .regularExpression) {
                homePath = String(homePath[userMatch])
                print("✅ Resolved to real user home: \(homePath)")
            }
        }

        let resolvedPath: String
        switch self {
        case .fonts:
            resolvedPath = "\(homePath)/Library/Fonts"
        case .designAssets:
            resolvedPath = "\(homePath)/Documents/Ventry/Design Assets"
        case .downloads:
            resolvedPath = "\(homePath)/Downloads"
        }

        return resolvedPath
    }

    /// Ensures the directory exists, creating it if necessary
    func ensureDirectoryExists() {
        let path = defaultPath
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
