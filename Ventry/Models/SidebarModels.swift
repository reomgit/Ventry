import Foundation
import SwiftUI

// MARK: - Starred Items
struct StarredItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let type: StarredItemType
    var path: String?
    
    init(id: UUID = UUID(), name: String, type: StarredItemType, path: String? = nil) {
        self.id = id
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

extension Notification.Name {
    static let starredItemsDidChange = Notification.Name("StarredItemsDidChange")
}

struct RemovedStarredItemRecord {
    let item: StarredItem
    let originalIndex: Int
}

final class StarredItemsStore {
    static let shared = StarredItemsStore()

    private let fileManager = FileManager.default
    private var cachedItems: [StarredItem] = []
    private var hasLoadedFromDisk = false

    private init() {}

    func currentItems() -> [StarredItem] {
        ensureLoadedFromDisk()
        return cachedItems
    }

    func reloadFromDisk() throws -> [StarredItem] {
        let loadedItems = try loadItemsFromDisk()
        cachedItems = loadedItems
        hasLoadedFromDisk = true
        postChangeNotification()
        return cachedItems
    }

    func isStarred(_ url: URL) -> Bool {
        let normalizedPath = normalizedPath(for: url)
        return currentItems().contains { $0.path == normalizedPath }
    }

    func add(items newItems: [StarredItem]) throws {
        try mutateItems { items in
            for item in newItems {
                guard let path = item.path, !path.isEmpty else { continue }
                if items.contains(where: { $0.path == path }) {
                    continue
                }
                items.append(item)
            }
        }
    }

    func remove(path: String) throws {
        try mutateItems { items in
            items.removeAll { $0.path == path }
        }
    }

    func remove(_ item: StarredItem) throws {
        try mutateItems { items in
            items.removeAll { $0.id == item.id }
        }
    }

    @discardableResult
    func removeItems(atOrInside url: URL) throws -> [RemovedStarredItemRecord] {
        let sourcePath = normalizedPath(for: url)
        var removedItems: [RemovedStarredItemRecord] = []

        try mutateItems { items in
            removedItems = items.enumerated().compactMap { index, item in
                guard let itemPath = item.path else { return nil }
                guard itemPath == sourcePath || itemPath.hasPrefix(sourcePath + "/") else {
                    return nil
                }
                return RemovedStarredItemRecord(item: item, originalIndex: index)
            }

            items.removeAll { item in
                guard let itemPath = item.path else { return false }
                return itemPath == sourcePath || itemPath.hasPrefix(sourcePath + "/")
            }
        }

        return removedItems
    }

    func restore(_ itemsToRestore: [RemovedStarredItemRecord]) throws {
        guard !itemsToRestore.isEmpty else { return }

        try mutateItems { items in
            for record in itemsToRestore.sorted(by: { $0.originalIndex < $1.originalIndex }) {
                let item = record.item
                guard let path = item.path, !path.isEmpty else { continue }
                if items.contains(where: { $0.path == path }) {
                    continue
                }

                let insertionIndex = min(max(record.originalIndex, 0), items.count)
                items.insert(item, at: insertionIndex)
            }
        }
    }

    func moveItems(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        try mutateItems { items in
            items.move(fromOffsets: source, toOffset: destination)
        }
    }

    func replacePathPrefix(from sourceURL: URL, to destinationURL: URL) throws {
        let sourcePath = normalizedPath(for: sourceURL)
        let destinationPath = normalizedPath(for: destinationURL)
        guard sourcePath != destinationPath else { return }

        try mutateItems { items in
            for index in items.indices {
                guard let itemPath = items[index].path else { continue }
                guard itemPath == sourcePath || itemPath.hasPrefix(sourcePath + "/") else { continue }

                let suffix = String(itemPath.dropFirst(sourcePath.count))
                let updatedPath = destinationPath + suffix
                items[index].path = updatedPath
                items[index].name = URL(fileURLWithPath: updatedPath).lastPathComponent
            }
        }
    }

    private func mutateItems(_ mutation: (inout [StarredItem]) -> Void) throws {
        ensureLoadedFromDisk()

        var updatedItems = cachedItems
        mutation(&updatedItems)

        try persist(items: updatedItems)
        cachedItems = updatedItems
        postChangeNotification()
    }

    private func ensureLoadedFromDisk() {
        guard !hasLoadedFromDisk else { return }

        do {
            cachedItems = try loadItemsFromDisk()
            hasLoadedFromDisk = true
        } catch {
            cachedItems = []
            hasLoadedFromDisk = true
            print("Failed to load starred items: \(error)")
        }
    }

    private func loadItemsFromDisk() throws -> [StarredItem] {
        let storageURL = AppStorageManager.shared.starredItemsStorageURL
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        return try JSONDecoder().decode([StarredItem].self, from: data)
    }

    private func persist(items: [StarredItem]) throws {
        let rootDirectory = AppStorageManager.shared.userVisibleRootDirectory
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: AppStorageManager.shared.starredItemsStorageURL, options: .atomic)
    }

    private func postChangeNotification() {
        NotificationCenter.default.post(name: .starredItemsDidChange, object: cachedItems)
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
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

    var installKey: String {
        "\(bundleIdentifier)::\(bundlePath ?? id.uuidString)"
    }

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
        let homePath = resolvedHomePath
        let resolvedPath: String
        switch self {
        case .fonts:
            resolvedPath = "\(homePath)/Library/Fonts"
        case .designAssets:
            resolvedPath = AppStorageManager.shared.designAssetsDirectory.path
        case .downloads:
            resolvedPath = "\(homePath)/Downloads"
        }

        return resolvedPath
    }

    var navigationPath: String {
        defaultPath
    }

    /// Ensures the directory exists, creating it if necessary
    func ensureDirectoryExists() {
        switch self {
        case .designAssets:
            break
        default:
            let path = defaultPath
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    private var resolvedHomePath: String {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        var homePath = homeURL.path

        if homePath.contains("/Library/Containers/"),
           let userMatch = homePath.range(of: #"/Users/[^/]+"#, options: .regularExpression) {
            homePath = String(homePath[userMatch])
        }

        return homePath
    }
}
