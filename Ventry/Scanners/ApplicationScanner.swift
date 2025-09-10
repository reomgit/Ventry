import Foundation
import AppKit
import Combine

class ApplicationScanner: ObservableObject {
    static let shared = ApplicationScanner()
    
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    
    
    private init() {}
    
    func scanForApplications() async -> [Application] {
        await MainActor.run {
            isScanning = true
            scanProgress = 0.0
        }
        
        var foundApplications: [Application] = []
        let applicationsPath = "/Applications"
        
        do {
            let applicationURLs = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: applicationsPath),
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                (try? url.resourceValues(forKeys: [.isApplicationKey]))?.isApplication == true
            }
            
            let totalApps = applicationURLs.count
            
            for (index, appURL) in applicationURLs.enumerated() {
                await MainActor.run {
                    scanProgress = Double(index) / Double(totalApps)
                }
                
                if let bundleIdentifier = getBundleIdentifier(for: appURL),
                   ApplicationDirectoryConfiguration.getSupportedApplications().contains(bundleIdentifier) {
                    
                    let appName = appURL.deletingPathExtension().lastPathComponent
                    let application = await createApplication(
                        name: appName,
                        bundleIdentifier: bundleIdentifier,
                        appURL: appURL
                    )
                    
                    if !application.directories.isEmpty {
                        foundApplications.append(application)
                    }
                }
            }
            
        } catch {
            print("Error scanning applications: \(error)")
        }
        
        await MainActor.run {
            isScanning = false
            scanProgress = 1.0
        }
        
        return foundApplications
    }
    
    private func getBundleIdentifier(for appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        return bundle.bundleIdentifier
    }
    
    private func createApplication(name: String, bundleIdentifier: String, appURL: URL) async -> Application {
        var directories: [AppDirectory] = []
        
        guard let directoryConfig = ApplicationDirectoryConfiguration.getDirectoryConfiguration(for: bundleIdentifier) else {
            return Application(name: name, bundleIdentifier: bundleIdentifier, directories: [])
        }
        
        let appSupportPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(name)
        
        let documentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
            .appendingPathComponent(name)
        
        // Scan common directory locations
        let searchPaths = [
            appSupportPath,
            documentsPath,
            appURL.appendingPathComponent("Contents/Resources"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences")
                .appendingPathComponent(name)
        ]
        
        for searchPath in searchPaths {
            directories.append(contentsOf: scanDirectoriesInPath(searchPath, config: directoryConfig))
        }
        
        return Application(
            name: name,
            bundleIdentifier: bundleIdentifier,
            iconName: nil,
            directories: directories
        )
    }
    
    private func scanDirectoriesInPath(_ basePath: URL, config: [String: [DirectoryType]]) -> [AppDirectory] {
        var directories: [AppDirectory] = []
        
        guard FileManager.default.fileExists(atPath: basePath.path) else {
            return directories
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for url in contents {
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                guard resourceValues?.isDirectory == true else { continue }
                
                let directoryName = url.lastPathComponent
                
                // Check if this directory matches any configured types
                for (configName, types) in config {
                    if directoryName.lowercased().contains(configName.lowercased()) ||
                       configName.lowercased().contains(directoryName.lowercased()) {
                        
                        for type in types {
                            let directory = AppDirectory(
                                name: directoryName,
                                path: url.path,
                                type: type
                            )
                            directories.append(directory)
                        }
                        break
                    }
                }
            }
            
        } catch {
            print("Error scanning directory \(basePath.path): \(error)")
        }
        
        return directories
    }
    
    func addCustomApplication(name: String, bundleIdentifier: String, customDirectories: [AppDirectory]) -> Application {
        return Application(
            name: name,
            bundleIdentifier: bundleIdentifier,
            iconName: nil,
            directories: customDirectories
        )
    }
    
    func getSupportedApplications() -> [String] {
        return ApplicationDirectoryConfiguration.getSupportedApplications()
    }
}