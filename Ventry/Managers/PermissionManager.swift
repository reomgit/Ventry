import Foundation
import AppKit
import Combine

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    static let applicationsPath = "/Applications"

    @Published var hasDirectoryAccess = false
    @Published var hasApplicationsAccess = false
    @Published var hasDocumentsAccess = false
    @Published var invalidPaths: [String] = []
    @Published var needsPathRevalidation = false

    private let bookmarksKey = "SecurityScopedBookmarks"
    private let legacyBookmarkPrefix = "SecurityBookmark_"
    private var activeSecurityScopedPaths = Set<String>()

    var documentsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private init() {
        refreshPermissionState()
    }

    var nextRequiredPermissionStep: PermissionStep {
        if !hasApplicationsAccess {
            return .applications
        }

        if !hasDocumentsAccess {
            return .documents
        }

        return .complete
    }

    func requestDirectoryAccess(for url: URL? = nil) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let openPanel = NSOpenPanel()
                openPanel.title = "Grant Directory Access"
                openPanel.message = "Ventry needs access to scan for applications and their associated directories. Please select a directory to grant access."
                openPanel.canChooseFiles = false
                openPanel.canChooseDirectories = true
                openPanel.allowsMultipleSelection = false
                openPanel.canCreateDirectories = false
                
                // Default to Applications folder
                if let url = url {
                    openPanel.directoryURL = url
                } else {
                    openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
                }
                
                openPanel.begin { response in
                    if response == .OK {
                        if let selectedURL = openPanel.url {
                            if let requestedURL = url,
                               !self.pathIsCovered(requestedURL.path, bySelectionAt: selectedURL.path) {
                                continuation.resume(returning: false)
                                return
                            }

                            self.storeSecurityScopedBookmark(for: selectedURL)
                            self.refreshPermissionState()
                            continuation.resume(returning: self.validatePath(url?.path ?? selectedURL.path))
                        } else {
                            continuation.resume(returning: false)
                        }
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func requestApplicationsDirectoryAccess() async -> Bool {
        let applicationsURL = URL(fileURLWithPath: Self.applicationsPath)
        return await requestDirectoryAccess(for: applicationsURL)
    }

    func requestDocumentsAccess() async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let openPanel = NSOpenPanel()
                openPanel.title = "Grant Documents Access"
                openPanel.message = "Ventry needs access to your Documents folder to store collections and design assets. Please select your Documents folder."
                openPanel.canChooseFiles = false
                openPanel.canChooseDirectories = true
                openPanel.allowsMultipleSelection = false
                openPanel.canCreateDirectories = true

                // Default to Documents folder
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                openPanel.directoryURL = documentsURL

                openPanel.begin { response in
                    if response == .OK, let selectedURL = openPanel.url {
                        guard let expectedDocumentsURL = self.documentsURL,
                              self.pathIsCovered(expectedDocumentsURL.path, bySelectionAt: selectedURL.path) else {
                            continuation.resume(returning: nil)
                            return
                        }

                        self.storeSecurityScopedBookmark(for: selectedURL)
                        self.refreshPermissionState()
                        continuation.resume(returning: expectedDocumentsURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    func storeSecurityScopedBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var bookmarks = storedBookmarks()
            bookmarks[normalizedPath(for: url)] = bookmarkData
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)

            print("Stored security bookmark for: \(url.path)")
        } catch {
            print("Failed to create security bookmark: \(error)")
        }
    }

    func restoreSecurityScopedAccess(for url: URL) -> Bool {
        let targetPath = normalizedPath(for: url)

        for candidatePath in bookmarkCandidatePaths(for: targetPath) {
            guard let bookmarkData = bookmarkData(for: candidatePath) else {
                continue
            }

            do {
                var isStale = false
                let restoredURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    removeBookmark(for: candidatePath)
                    continue
                }

                let restoredPath = normalizedPath(for: restoredURL)
                if activeSecurityScopedPaths.contains(restoredPath) {
                    return true
                }

                if restoredURL.startAccessingSecurityScopedResource() {
                    activeSecurityScopedPaths.insert(restoredPath)
                    return true
                }
            } catch {
                print("Failed to restore security bookmark: \(error)")
                removeBookmark(for: candidatePath)
            }
        }

        return false
    }

    func checkDirectoryAccess(for path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        // Try to restore existing access first
        if restoreSecurityScopedAccess(for: url) {
            return true
        }
        
        // Check if we can read the directory
        return FileManager.default.isReadableFile(atPath: path)
    }

    func stopAccessingSecurityScopedResource(for url: URL) {
        let path = normalizedPath(for: url)
        guard activeSecurityScopedPaths.remove(path) != nil else { return }
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Path Validation

    /// Validates multiple paths and returns a list of inaccessible ones
    func validatePaths(_ paths: [String]) -> [String] {
        var inaccessiblePaths: [String] = []

        for path in paths {
            if !validatePath(path) {
                inaccessiblePaths.append(path)
            }
        }

        return inaccessiblePaths
    }

    /// Validates a single path for accessibility
    func validatePath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        // Check if path exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("Path does not exist: \(path)")
            return false
        }

        // Try to restore existing security-scoped access
        if restoreSecurityScopedAccess(for: url) {
            return true
        }

        // Check if we can read the directory/file
        let isReadable = FileManager.default.isReadableFile(atPath: path)
        if !isReadable {
            print("Path is not readable: \(path)")
        }

        return isReadable
    }

    /// Checks if a path is an alias and resolves it
    func resolveAlias(at path: String) -> String? {
        let url = URL(fileURLWithPath: path)

        do {
            let resourceValues = try url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])

            if resourceValues.isAliasFile == true || resourceValues.isSymbolicLink == true {
                let originalURL = try URL(resolvingAliasFileAt: url)
                return originalURL.path
            }

            return path
        } catch {
            print("Failed to resolve alias at \(path): \(error)")
            return nil
        }
    }

    /// Requests access to a specific path that was found to be inaccessible
    func requestAccessToPath(_ path: String) async -> Bool {
        let url = URL(fileURLWithPath: path)

        var isDirectory: ObjCBool = false
        let requestedURL: URL
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            requestedURL = url
        } else {
            requestedURL = url.deletingLastPathComponent()
        }

        return await requestDirectoryAccess(for: requestedURL)
    }

    /// Validates all required paths and updates published state
    func validateRequiredPaths(_ paths: [String]) {
        let invalid = validatePaths(paths)

        DispatchQueue.main.async { [weak self] in
            self?.invalidPaths = invalid
            self?.needsPathRevalidation = !invalid.isEmpty
        }
    }

    func refreshPermissionState() {
        let applicationsAccess = hasSecurityScopedAccess(for: Self.applicationsPath)
        let documentsAccess = documentsURL.map { hasSecurityScopedAccess(for: $0.path) } ?? false

        DispatchQueue.main.async { [weak self] in
            self?.hasApplicationsAccess = applicationsAccess
            self?.hasDocumentsAccess = documentsAccess
            self?.hasDirectoryAccess = applicationsAccess && documentsAccess
        }
    }

    private func bookmarkCandidatePaths(for path: String) -> [String] {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        var candidates: [String] = []
        var currentURL = URL(fileURLWithPath: standardizedPath)

        while true {
            let currentPath = currentURL.path
            candidates.append(currentPath)

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentPath {
                break
            }

            currentURL = parentURL
        }

        return candidates
    }

    private func bookmarkData(for path: String) -> Data? {
        if let bookmark = storedBookmarks()[path] {
            return bookmark
        }

        return UserDefaults.standard.data(forKey: legacyKey(for: path))
    }

    private func removeBookmark(for path: String) {
        var bookmarks = storedBookmarks()
        bookmarks.removeValue(forKey: path)
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
        UserDefaults.standard.removeObject(forKey: legacyKey(for: path))
        activeSecurityScopedPaths.remove(path)
        refreshPermissionState()
    }

    private func storedBookmarks() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] ?? [:]
    }

    private func legacyKey(for path: String) -> String {
        "\(legacyBookmarkPrefix)\(path.replacingOccurrences(of: "/", with: "_"))"
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func hasSecurityScopedAccess(for path: String) -> Bool {
        restoreSecurityScopedAccess(for: URL(fileURLWithPath: path))
    }

    private func pathIsCovered(_ targetPath: String, bySelectionAt selectedPath: String) -> Bool {
        let normalizedTarget = URL(fileURLWithPath: targetPath).standardizedFileURL.path
        let normalizedSelection = URL(fileURLWithPath: selectedPath).standardizedFileURL.path

        if normalizedSelection == "/" {
            return true
        }

        return normalizedTarget == normalizedSelection ||
            normalizedTarget.hasPrefix(normalizedSelection + "/")
    }
}

extension PermissionManager {
    enum PermissionStep {
        case applications
        case documents
        case complete
    }
}
