import Foundation
import AppKit
import Combine

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var hasDirectoryAccess = false
    @Published var invalidPaths: [String] = []
    @Published var needsPathRevalidation = false

    private init() {
        // Check if we already have access to /Applications
        let applicationsPath = "/Applications"
        if checkDirectoryAccess(for: applicationsPath) {
            hasDirectoryAccess = true
        }
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
                        // Store security-scoped bookmark for future access
                        if let selectedURL = openPanel.url {
                            self.storeSecurityScopedBookmark(for: selectedURL)
                            self.hasDirectoryAccess = true
                            continuation.resume(returning: true)
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
        let applicationsURL = URL(fileURLWithPath: "/Applications")
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
                        // Store security-scoped bookmark for future access
                        self.storeSecurityScopedBookmark(for: selectedURL)
                        continuation.resume(returning: selectedURL)
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
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let key = "SecurityBookmark_\(url.path.replacingOccurrences(of: "/", with: "_"))"
            UserDefaults.standard.set(bookmarkData, forKey: key)

            print("Stored security bookmark for: \(url.path)")
        } catch {
            print("Failed to create security bookmark: \(error)")
        }
    }
    
    func restoreSecurityScopedAccess(for url: URL) -> Bool {
        let key = "SecurityBookmark_\(url.path.replacingOccurrences(of: "/", with: "_"))"
        
        guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
            return false
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
                // Bookmark is stale, need to request access again
                return false
            }
            
            // Start accessing the security-scoped resource
            _ = restoredURL.startAccessingSecurityScopedResource()
            return true
        } catch {
            print("Failed to restore security bookmark: \(error)")
            return false
        }
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
        return await requestDirectoryAccess(for: url.deletingLastPathComponent())
    }

    /// Validates all required paths and updates published state
    func validateRequiredPaths(_ paths: [String]) {
        let invalid = validatePaths(paths)

        DispatchQueue.main.async { [weak self] in
            self?.invalidPaths = invalid
            self?.needsPathRevalidation = !invalid.isEmpty
        }
    }
}