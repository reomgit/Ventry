import Foundation
import UniformTypeIdentifiers

class DirectoryScanner {
    static let shared = DirectoryScanner()
    
    private init() {}
    
    func scanDirectory(_ directory: AppDirectory) async -> Collection {
        let assets = await scanForAssets(at: directory.path)
        
        return Collection(
            name: "\(directory.name) (\(directory.type.rawValue))",
            assets: assets
        )
    }
    
    func scanForAssets(at path: String) async -> [Asset] {
        var assets: [Asset] = []
        
        guard FileManager.default.fileExists(atPath: path) else {
            return assets
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            
            for item in contents {
                let itemPath = "\(path)/\(item)"
                var isDirectory: ObjCBool = false
                
                guard FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory) else {
                    continue
                }
                
                if isDirectory.boolValue {
                    // Recursively scan subdirectories (limit depth to avoid infinite loops)
                    let subdirectoryAssets = await scanForAssets(at: itemPath)
                    assets.append(contentsOf: subdirectoryAssets)
                } else {
                    // Create asset for file
                    if let asset = createAssetFromFile(name: item, path: itemPath) {
                        assets.append(asset)
                    }
                }
            }
        } catch {
            print("Error scanning directory \(path): \(error)")
        }
        
        return assets
    }
    
    private func createAssetFromFile(name: String, path: String) -> Asset? {
        let url = URL(fileURLWithPath: path)
        let assetType = determineAssetType(for: url)
        
        return Asset(name: name, type: assetType)
    }
    
    private func determineAssetType(for url: URL) -> AssetType {
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
              let contentType = resourceValues.contentType else {
            return .other
        }
        
        if contentType.conforms(to: .image) {
            return .image
        } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return .video
        } else if contentType.conforms(to: .audio) {
            return .audio
        } else if contentType.conforms(to: .text) || 
                  contentType.conforms(to: .pdf) ||
                  contentType.conforms(to: .rtf) ||
                  contentType.conforms(to: .plainText) {
            return .document
        } else if contentType.conforms(to: .archive) ||
                  contentType.conforms(to: .zip) ||
                  url.pathExtension.lowercased() == "rar" ||
                  url.pathExtension.lowercased() == "7z" {
            return .archive
        }
        
        // Check for common creative file extensions
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "aep", "prproj", "fcpx", "c4d", "blend", "ma", "mb":
            return .document
        case "aiff", "wav", "flac", "ogg":
            return .audio
        case "mov", "mp4", "avi", "mkv", "webm":
            return .video
        case "psd", "ai", "sketch", "fig", "xd":
            return .image
        default:
            return .other
        }
    }
    
    func createCollectionFromDirectory(_ directory: AppDirectory, completion: @escaping (Collection) -> Void) {
        Task {
            let collection = await scanDirectory(directory)
            await MainActor.run {
                completion(collection)
            }
        }
    }
}