import Foundation

struct ApplicationDirectoryConfiguration {
    static let supportedApplications: [String: [String: [DirectoryType]]] = [
        // Adobe After Effects - Template for manual directory configuration
        // Replace these paths with actual directories you want to monitor
        "com.adobe.AfterEffects": [
            "/Applications/Adobe After Effects 2024/Plug-ins": [.effects],
            "/Library/Application Support/Adobe/Common/Plug-Ins": [.effects],
            "~/Library/Application Support/Adobe/After Effects/User Presets": [.presets],
            "~/Documents/Adobe/After Effects/User Presets": [.presets],
            "~/Documents/Adobe/After Effects/Templates": [.templates],
            "~/Library/Application Support/Adobe/After Effects/Scripts": [.scripts]
        ]
    ]
    
    static func getDirectoryConfiguration(for bundleIdentifier: String) -> [String: [DirectoryType]]? {
        return supportedApplications[bundleIdentifier]
    }
    
    static func getSupportedApplications() -> [String] {
        return Array(supportedApplications.keys)
    }
}