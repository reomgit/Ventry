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
        let requestedURL = (url ?? URL(fileURLWithPath: "/Applications")).standardizedFileURL
        let accessGranted = canAccessURLDirectly(requestedURL)

        if accessGranted {
            refreshPermissionState()
        }

        return accessGranted
    }
    
    func requestApplicationsDirectoryAccess() async -> Bool {
        let applicationsURL = URL(fileURLWithPath: Self.applicationsPath)
        return await requestDirectoryAccess(for: applicationsURL)
    }

    func requestDocumentsAccess() async -> URL? {
        guard let documentsURL else {
            return nil
        }

        if canAccessURLDirectly(documentsURL) {
            refreshPermissionState()
            return documentsURL
        }

        return nil
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

        if canAccessURLDirectly(url) {
            return true
        }

        // Try to restore existing access first
        if restoreSecurityScopedAccess(for: url) {
            return true
        }

        return false
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

        let isAccessible = canAccessURLDirectly(url)
        if !isAccessible {
            print("Path is not readable: \(path)")
        }

        return isAccessible
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
    func requestAccessToPath(_ path: String) async -> PathAccessRequestResult {
        if isManagedDocumentsPath(path) {
            return requestSystemManagedDocumentsAccess(for: path)
        }

        let url = URL(fileURLWithPath: path)

        var isDirectory: ObjCBool = false
        let requestedURL: URL
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            requestedURL = url
        } else {
            requestedURL = url.deletingLastPathComponent()
        }

        let granted = await requestDirectoryAccess(for: requestedURL)
        return granted ? .granted : .denied
    }

    func isSystemManagedDocumentsPath(_ path: String) -> Bool {
        isManagedDocumentsPath(path)
    }

    @discardableResult
    func openDocumentsPrivacySettings() -> Bool {
        if let deepLinkURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"),
           NSWorkspace.shared.open(deepLinkURL) {
            return true
        }

        if let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security"),
           NSWorkspace.shared.open(privacyURL) {
            return true
        }

        let settingsAppURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        return NSWorkspace.shared.open(settingsAppURL)
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
        let storageReady = AppStorageManager.shared.prepareDirectories()
        let applicationsAccess = FileManager.default.isReadableFile(atPath: Self.applicationsPath)
        let documentsAccess = documentsURL.map { FileManager.default.isReadableFile(atPath: $0.path) } ?? false

        DispatchQueue.main.async { [weak self] in
            self?.hasApplicationsAccess = applicationsAccess
            self?.hasDocumentsAccess = documentsAccess
            self?.hasDirectoryAccess = storageReady
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

    private func canAccessURLDirectly(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        if isDirectory.boolValue {
            do {
                _ = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                return true
            } catch {
                return false
            }
        }

        return FileManager.default.isReadableFile(atPath: url.path)
    }

    private func isManagedDocumentsPath(_ path: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let documentsPath = AppStorageManager.shared.documentsDirectory.path
        let designAssetsPath = AppStorageManager.shared.designAssetsDirectory.path

        return normalizedPath == documentsPath ||
            normalizedPath == designAssetsPath ||
            normalizedPath.hasPrefix(designAssetsPath + "/")
    }

    private func requestSystemManagedDocumentsAccess(for path: String) -> PathAccessRequestResult {
        let documentsAccess = documentsAccessStatus()
        guard documentsAccess == .granted else {
            if documentsAccess == .blockedByDocumentsPrivacy {
                print("Documents access is blocked by macOS privacy controls")
            }
            return documentsAccess
        }

        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        if normalizedPath == AppStorageManager.shared.designAssetsDirectory.path ||
           normalizedPath.hasPrefix(AppStorageManager.shared.designAssetsDirectory.path + "/") {
            guard AppStorageManager.shared.prepareDesignAssetsDirectory() else {
                return .denied
            }
        }

        return validatePath(path) ? .granted : .denied
    }

    private func documentsAccessStatus() -> PathAccessRequestResult {
        let documentsURL = AppStorageManager.shared.documentsDirectory

        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return .granted
        } catch {
            print("Failed to read Documents while requesting access: \(error)")
            return isDocumentsPrivacyError(error) ? .blockedByDocumentsPrivacy : .denied
        }
    }

    private func isDocumentsPrivacyError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileReadNoPermissionError || nsError.code == NSFileWriteNoPermissionError {
            return true
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlyingError.domain == NSPOSIXErrorDomain,
           underlyingError.code == EPERM || underlyingError.code == EACCES {
            return true
        }

        return false
    }
}

extension PermissionManager {
    enum PathAccessRequestResult: Equatable {
        case granted
        case blockedByDocumentsPrivacy
        case denied
    }

    enum PermissionStep {
        case applications
        case documents
        case complete
    }
}
