import Foundation

final class AppStorageManager {
    static let shared = AppStorageManager()

    let internalRootDirectory: URL
    let collectionsDirectory: URL
    let designAssetsDirectory: URL

    private init() {
        let applicationSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        internalRootDirectory = applicationSupportDirectory.appendingPathComponent("Ventry", isDirectory: true)
        collectionsDirectory = internalRootDirectory.appendingPathComponent("Collections", isDirectory: true)
        designAssetsDirectory = Self.resolvedDocumentsDirectory()
            .appendingPathComponent("Ventry", isDirectory: true)
            .appendingPathComponent("Design Assets", isDirectory: true)
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
            print("Failed to prepare design assets directory: \(error)")
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
