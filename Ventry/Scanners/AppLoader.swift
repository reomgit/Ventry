import Foundation
import AppKit

/// Loads all .app bundles from the Applications folder and subfolders
class AppLoader {
    static let shared = AppLoader()

    private init() {}

    /// Represents a discovered application bundle before scanning its directories
    struct LoadedApp: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let bundlePath: String
        let bundleIdentifier: String?
        let version: String?
        let isSupported: Bool

        var installKey: String {
            "\(bundleIdentifier ?? "unknown")::\(bundlePath)"
        }

        static func == (lhs: LoadedApp, rhs: LoadedApp) -> Bool {
            lhs.bundlePath == rhs.bundlePath
        }
    }

    /// Discovers all .app files in /Applications and subdirectories
    func loadAllApplications(supportedApps: [String: SupportedApplication]) async -> [LoadedApp] {
        let applicationsPath = "/Applications"
        var loadedApps: [LoadedApp] = []

        guard FileManager.default.fileExists(atPath: applicationsPath) else {
            print("Applications folder not found")
            return loadedApps
        }

        // Recursively find all .app bundles
        let appBundles = await findAppBundles(at: applicationsPath)

        // Convert to LoadedApp objects
        for bundlePath in appBundles {
            if let loadedApp = createLoadedApp(from: bundlePath, supportedApps: supportedApps) {
                loadedApps.append(loadedApp)
            }
        }

        return loadedApps.sorted { left, right in
            let nameOrder = left.name.localizedCaseInsensitiveCompare(right.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            let versionOrder = SupportedPathResolver.compareVersionStrings(left.version, right.version)
            if versionOrder != .orderedSame {
                return versionOrder == .orderedDescending
            }

            return left.bundlePath.localizedStandardCompare(right.bundlePath) == .orderedAscending
        }
    }

    /// Recursively finds all .app bundles in a directory
    private func findAppBundles(at path: String, maxDepth: Int = 5, currentDepth: Int = 0) async -> [String] {
        var appBundles: [String] = []

        // Prevent infinite recursion
        guard currentDepth < maxDepth else {
            return appBundles
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)

            for item in contents {
                let itemPath = "\(path)/\(item)"
                var isDirectory: ObjCBool = false

                guard FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory) else {
                    continue
                }

                // Check if it's an .app bundle
                if item.hasSuffix(".app") && isDirectory.boolValue {
                    appBundles.append(itemPath)
                } else if isDirectory.boolValue && !item.hasPrefix(".") {
                    // Recursively search subdirectories (skip hidden folders)
                    let subdirectoryBundles = await findAppBundles(
                        at: itemPath,
                        maxDepth: maxDepth,
                        currentDepth: currentDepth + 1
                    )
                    appBundles.append(contentsOf: subdirectoryBundles)
                }
            }
        } catch {
            print("Error reading directory \(path): \(error)")
        }

        return appBundles
    }

    /// Creates a LoadedApp from a bundle path
    private func createLoadedApp(from bundlePath: String, supportedApps: [String: SupportedApplication]) -> LoadedApp? {
        let bundleURL = URL(fileURLWithPath: bundlePath)
        let appName = bundleURL.deletingPathExtension().lastPathComponent

        // Read bundle metadata once
        let metadata = getBundleMetadata(from: bundlePath)
        let bundleIdentifier = metadata.bundleIdentifier

        // Check if this app is supported
        let isSupported: Bool
        if let bundleID = bundleIdentifier {
            isSupported = supportedApps.keys.contains(bundleID)
        } else {
            isSupported = false
        }

        return LoadedApp(
            name: appName,
            bundlePath: bundlePath,
            bundleIdentifier: bundleIdentifier,
            version: metadata.version,
            isSupported: isSupported
        )
    }

    /// Reads bundle metadata from an app bundle's Info.plist
    private func getBundleMetadata(from bundlePath: String) -> (bundleIdentifier: String?, version: String?) {
        let infoPlistPath = "\(bundlePath)/Contents/Info.plist"

        guard FileManager.default.fileExists(atPath: infoPlistPath),
              let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return (nil, nil)
        }

        let bundleIdentifier = plist["CFBundleIdentifier"] as? String
        let shortVersion = (plist["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (plist["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let version = (shortVersion?.isEmpty == false ? shortVersion : nil) ?? (buildVersion?.isEmpty == false ? buildVersion : nil)

        return (bundleIdentifier, version)
    }

    /// Gets the app icon for a given bundle path
    func getAppIcon(for bundlePath: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        return workspace.icon(forFile: bundlePath)
    }
}
