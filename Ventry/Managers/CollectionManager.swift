import Foundation

class CollectionManager {
    static let shared = CollectionManager()

    private let collectionsDirectory: URL

    init() {
        // Store in ~/Documents/Ventry/Collections/ (user's real Documents, not container)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let ventryDir = homeDir.appendingPathComponent("Documents/Ventry/Collections")
        self.collectionsDirectory = ventryDir

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: ventryDir,
            withIntermediateDirectories: true
        )
    }

    func saveCollection(_ collection: Collection) throws {
        let fileURL = collectionsDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(collection)
        try data.write(to: fileURL)

        // Store security-scoped bookmark for the collection's path
        storeBookmark(for: collection.path)

        print("Saved collection '\(collection.name)' to \(fileURL.path)")
    }

    func loadAllCollections() throws -> [Collection] {
        // Check if directory exists
        guard FileManager.default.fileExists(atPath: collectionsDirectory.path) else {
            print("Collections directory does not exist yet: \(collectionsDirectory.path)")
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: collectionsDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var collections: [Collection] = []

        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let collection = try decoder.decode(Collection.self, from: data)

                // Restore security-scoped access for the collection's path
                _ = PermissionManager.shared.restoreSecurityScopedAccess(
                    for: URL(fileURLWithPath: collection.path)
                )

                collections.append(collection)
                print("Loaded collection '\(collection.name)' from \(fileURL.path)")
            } catch {
                print("Failed to load collection from \(fileURL): \(error)")
            }
        }

        return collections
    }

    func deleteCollection(_ id: UUID) throws {
        let fileURL = collectionsDirectory.appendingPathComponent("\(id.uuidString).json")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("Deleted collection file: \(fileURL.path)")
        } else {
            print("Collection file not found for deletion: \(fileURL.path)")
        }
    }

    func refreshCollection(_ collection: Collection) async throws -> Collection {
        // Rescan the collection's source directory
        let assets = await DirectoryScanner.shared.scanForAssets(at: collection.path)

        var updatedCollection = collection
        updatedCollection.updateAssets(assets)

        // Save updated collection
        try saveCollection(updatedCollection)

        print("Refreshed collection '\(collection.name)' - found \(assets.count) assets")
        return updatedCollection
    }

    private func storeBookmark(for path: String) {
        let url = URL(fileURLWithPath: path)
        PermissionManager.shared.storeSecurityScopedBookmark(for: url)
    }
}
