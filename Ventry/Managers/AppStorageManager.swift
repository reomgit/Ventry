import Foundation

final class AppStorageManager {
    static let shared = AppStorageManager()

    let internalRootDirectory: URL
    let collectionsDirectory: URL
    let documentsDirectory: URL
    let userVisibleRootDirectory: URL
    let designAssetsDirectory: URL
    let starredItemsStorageURL: URL

    private init() {
        let applicationSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        internalRootDirectory = applicationSupportDirectory.appendingPathComponent("Ventry", isDirectory: true)
        collectionsDirectory = internalRootDirectory.appendingPathComponent("Collections", isDirectory: true)
        documentsDirectory = Self.resolvedDocumentsDirectory()
        userVisibleRootDirectory = documentsDirectory
            .appendingPathComponent("Ventry", isDirectory: true)
        designAssetsDirectory = userVisibleRootDirectory
            .appendingPathComponent("Design Assets", isDirectory: true)
        starredItemsStorageURL = userVisibleRootDirectory
            .appendingPathComponent("Starred Items.json", isDirectory: false)
    }

    @discardableResult
    func prepareDirectories() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: collectionsDirectory,
                withIntermediateDirectories: true
            )
            return true
        } catch {
            print("Failed to prepare app storage directories: \(error)")
            return false
        }
    }

    @discardableResult
    func prepareDesignAssetsDirectory() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: designAssetsDirectory,
                withIntermediateDirectories: true
            )
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func prepareUserVisibleRootDirectory() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: userVisibleRootDirectory,
                withIntermediateDirectories: true
            )
            return true
        } catch {
            return false
        }
    }

    private static func resolvedDocumentsDirectory() -> URL {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        var homePath = homeURL.path

        if homePath.contains("/Library/Containers/"),
           let userMatch = homePath.range(of: #"/Users/[^/]+"#, options: .regularExpression) {
            homePath = String(homePath[userMatch])
        }

        return URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
    }
}
