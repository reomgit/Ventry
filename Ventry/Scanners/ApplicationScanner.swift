import Foundation
import AppKit
import Combine

class ApplicationScanner: ObservableObject {
    static let shared = ApplicationScanner()
    
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var multipleInstallationsFound: [String: [DetectedApplication]] = [:]
    
    private let permissionManager = PermissionManager.shared
    
    struct DetectedApplication {
        let name: String
        let version: String?
        let bundleIdentifier: String
        let appURL: URL
        let installationPath: String
    }
    
    private init() {}
    
    func scanForApplications() async -> [Application] {
        await MainActor.run {
            isScanning = true
            scanProgress = 0.0
            multipleInstallationsFound.removeAll()
        }
        
        // Check for directory access permission first
        let applicationsPath = "/Applications"
        if !permissionManager.checkDirectoryAccess(for: applicationsPath) {
            let accessGranted = await permissionManager.requestApplicationsDirectoryAccess()
            if !accessGranted {
                await MainActor.run {
                    isScanning = false
                    scanProgress = 0.0
                }
                return []
            }
        }
        
        var foundApplications: [Application] = []
        let detectedApps = await scanApplicationsDirectory()
        
        // Group apps by base name to detect multiple installations
        let groupedApps = groupApplicationsByBaseName(detectedApps)
        
        let totalGroups = groupedApps.count
        var processedGroups = 0
        
        for (baseName, apps) in groupedApps {
            await MainActor.run {
                scanProgress = Double(processedGroups) / Double(totalGroups)
            }
            
            if apps.count > 1 {
                // Multiple installations found - store for user selection
                await MainActor.run {
                    multipleInstallationsFound[baseName] = apps
                }
                
                // For now, use the latest version
                if let latestApp = getLatestVersion(from: apps) {
                    let application = await createApplication(from: latestApp)
                    if !application.directories.isEmpty {
                        foundApplications.append(application)
                    }
                }
            } else if let app = apps.first {
                // Single installation
                let application = await createApplication(from: app)
                if !application.directories.isEmpty {
                    foundApplications.append(application)
                }
            }
            
            processedGroups += 1
        }
        
        await MainActor.run {
            isScanning = false
            scanProgress = 1.0
        }
        
        return foundApplications
    }
    
    private func scanApplicationsDirectory() async -> [DetectedApplication] {
        var detectedApps: [DetectedApplication] = []
        let applicationsPath = "/Applications"
        
        do {
            let applicationURLs = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: applicationsPath),
                includingPropertiesForKeys: [.isApplicationKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                // Check if it's an application bundle
                if url.pathExtension.lowercased() == "app" {
                    return true
                }
                
                // Also check the resource type
                let resourceValues = try? url.resourceValues(forKeys: [.isApplicationKey])
                return resourceValues?.isApplication == true
            }
            
            for appURL in applicationURLs {
                if let bundleIdentifier = getBundleIdentifier(for: appURL),
                   let baseAppName = getBaseApplicationName(from: appURL.deletingPathExtension().lastPathComponent),
                   ApplicationDirectoryConfiguration.getSupportedApplications().contains(bundleIdentifier) || 
                   isKnownApplication(baseAppName) {
                    
                    let version = getApplicationVersion(for: appURL)
                    let detectedApp = DetectedApplication(
                        name: appURL.deletingPathExtension().lastPathComponent,
                        version: version,
                        bundleIdentifier: bundleIdentifier,
                        appURL: appURL,
                        installationPath: appURL.path
                    )
                    
                    detectedApps.append(detectedApp)
                }
            }
            
        } catch {
            print("Error scanning applications directory: \(error)")
        }
        
        return detectedApps
    }
    
    private func getBundleIdentifier(for appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        return bundle.bundleIdentifier
    }
    
    private func getApplicationVersion(for appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL),
              let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }
    
    private func getBaseApplicationName(from fullName: String) -> String? {
        // First, try to match against known display names
        let patterns = ApplicationDirectoryConfiguration.getAvailableApplicationDisplayNames()
        
        for pattern in patterns {
            // Check if the full name contains the pattern (ignoring case and year)
            let cleanFullName = fullName.lowercased()
            let cleanPattern = pattern.lowercased()
            
            if cleanFullName.contains(cleanPattern) || cleanPattern.contains(cleanFullName) {
                return pattern
            }
        }
        
        // For Adobe apps specifically, remove year patterns and try again
        let yearPattern = #"\s+(20\d{2}|202[0-9])"#
        if let regex = try? NSRegularExpression(pattern: yearPattern) {
            let range = NSRange(location: 0, length: fullName.utf16.count)
            let baseName = regex.stringByReplacingMatches(in: fullName, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            
            // Try matching the year-stripped name
            for pattern in patterns {
                if baseName.lowercased().contains(pattern.lowercased()) || 
                   pattern.lowercased().contains(baseName.lowercased()) {
                    return pattern
                }
            }
            
            return baseName
        }
        
        return fullName
    }
    
    private func isKnownApplication(_ baseName: String) -> Bool {
        let knownApps = ApplicationDirectoryConfiguration.getAvailableApplicationDisplayNames()
        
        return knownApps.contains { knownApp in
            baseName.lowercased().contains(knownApp.lowercased()) ||
            knownApp.lowercased().contains(baseName.lowercased())
        }
    }
    
    private func groupApplicationsByBaseName(_ apps: [DetectedApplication]) -> [String: [DetectedApplication]] {
        var grouped: [String: [DetectedApplication]] = [:]
        
        for app in apps {
            let baseName = getBaseApplicationName(from: app.name) ?? app.name
            
            if grouped[baseName] == nil {
                grouped[baseName] = []
            }
            grouped[baseName]?.append(app)
        }
        
        return grouped
    }
    
    private func getLatestVersion(from apps: [DetectedApplication]) -> DetectedApplication? {
        return apps.max { app1, app2 in
            // Compare by version if available
            if let version1 = app1.version, let version2 = app2.version {
                return compareVersions(version1, version2) == .orderedAscending
            }
            
            // Fall back to name comparison (looking for year numbers)
            return extractYear(from: app1.name) < extractYear(from: app2.name)
        }
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        return version1.compare(version2, options: .numeric)
    }
    
    private func extractYear(from name: String) -> Int {
        let yearPattern = #"20\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: yearPattern) else { return 0 }
        
        let range = NSRange(location: 0, length: name.utf16.count)
        if let match = regex.firstMatch(in: name, range: range) {
            let yearString = String(name[Range(match.range, in: name)!])
            return Int(yearString) ?? 0
        }
        
        return 0
    }
    
    private func createApplication(from detectedApp: DetectedApplication) async -> Application {
        return await createApplication(
            name: detectedApp.name,
            bundleIdentifier: detectedApp.bundleIdentifier,
            appURL: detectedApp.appURL
        )
    }
    
    private func createApplication(name: String, bundleIdentifier: String, appURL: URL) async -> Application {
        var directories: [AppDirectory] = []
        
        guard let directoryConfig = ApplicationDirectoryConfiguration.getDirectoryConfiguration(for: bundleIdentifier) else {
            return Application(name: name, bundleIdentifier: bundleIdentifier, directories: [])
        }
        
        // Add plugins from the app bundle itself (for versioned Adobe apps)
        let pluginsPath = appURL.appendingPathComponent("Plug-ins")
        if FileManager.default.fileExists(atPath: pluginsPath.path) {
            let directory = AppDirectory(
                name: "Plug-ins",
                path: pluginsPath.path,
                type: .plugins
            )
            directories.append(directory)
        }
        
        // Add configured paths from the configuration
        for (path, types) in directoryConfig {
            for type in types {
                let expandedPath = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                
                // Check if directory exists
                if FileManager.default.fileExists(atPath: expandedPath) {
                    let directoryName = URL(fileURLWithPath: expandedPath).lastPathComponent
                    let directory = AppDirectory(
                        name: directoryName,
                        path: expandedPath,
                        type: type
                    )
                    directories.append(directory)
                }
            }
        }
        
        return Application(
            name: name,
            bundleIdentifier: bundleIdentifier,
            iconName: nil,
            directories: directories
        )
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
    
    func selectApplicationVersion(baseName: String, selectedApp: DetectedApplication) async -> Application? {
        await MainActor.run {
            // Remove from multiple installations since user has selected
            multipleInstallationsFound[baseName] = nil
        }
        
        let application = await createApplication(from: selectedApp)
        return application.directories.isEmpty ? nil : application
    }
    
    func getAvailableApplications() async -> [String] {
        let detectedApps = await scanApplicationsDirectory()
        let baseNames = Set(detectedApps.compactMap { getBaseApplicationName(from: $0.name) })
        
        // Filter to only include applications that are configured and supported
        let availableConfiguredApps = baseNames.filter { baseName in
            ApplicationDirectoryConfiguration.getAvailableApplicationDisplayNames().contains(baseName)
        }
        
        return Array(availableConfiguredApps).sorted()
    }
    
    func getInstalledApplicationsCount() async -> Int {
        let availableApps = await getAvailableApplications()
        return availableApps.count
    }
    
    func isApplicationInstalled(_ applicationName: String) async -> Bool {
        let availableApps = await getAvailableApplications()
        return availableApps.contains(applicationName)
    }
    
    func hasMultipleInstallations(for baseName: String) -> Bool {
        return multipleInstallationsFound[baseName]?.count ?? 0 > 1
    }
    
    func getInstallations(for baseName: String) -> [DetectedApplication] {
        return multipleInstallationsFound[baseName] ?? []
    }
}