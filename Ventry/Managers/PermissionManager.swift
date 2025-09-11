import Foundation
import AppKit
import Combine

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var hasDirectoryAccess = false
    
    private init() {}
    
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
    
    private func storeSecurityScopedBookmark(for url: URL) {
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
}