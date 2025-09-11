import Foundation

struct ApplicationDirectoryConfiguration {
    static let supportedApplications: [String: [String: [DirectoryType]]] = [
        // Adobe After Effects
        "com.adobe.AfterEffects": [
            "~/Library/Application Support/Adobe/After Effects/User Presets": [.presets],
            "~/Documents/Adobe/After Effects/User Presets": [.presets],
            "~/Library/Application Support/Adobe/After Effects/Templates": [.templates],
            "~/Library/Application Support/Adobe/After Effects/Scripts": [.scripts],
            "~/Library/Application Support/Adobe/After Effects/Expressions": [.scripts]
        ],
        
        // Adobe Premiere Pro
        "com.adobe.PremierePro": [
            "~/Library/Application Support/Adobe/Premiere Pro/User Presets": [.presets],
            "~/Documents/Adobe/Premiere Pro/User Presets": [.presets],
            "~/Library/Application Support/Adobe/Premiere Pro/Templates": [.templates],
            "~/Library/Application Support/Adobe/Premiere Pro/Motion Graphics Templates": [.templates],
            "~/Library/Application Support/Adobe/Premiere Pro/Effects": [.effects]
        ],
        
        // Adobe Photoshop
        "com.adobe.Photoshop": [
            "~/Library/Application Support/Adobe/Adobe Photoshop/Presets/Actions": [.presets],
            "~/Library/Application Support/Adobe/Adobe Photoshop/Presets/Brushes": [.presets],
            "~/Library/Application Support/Adobe/Adobe Photoshop/Presets/Patterns": [.presets],
            "~/Library/Application Support/Adobe/Adobe Photoshop/Presets/Gradients": [.presets],
            "~/Library/Application Support/Adobe/Adobe Photoshop/Presets/Styles": [.presets],
            "~/Library/Application Support/Adobe/Adobe Photoshop/Presets/Custom Shapes": [.presets]
        ],
        
        // Adobe Illustrator
        "com.adobe.Illustrator": [
            "~/Library/Application Support/Adobe/Adobe Illustrator/Presets/Brushes": [.presets],
            "~/Library/Application Support/Adobe/Adobe Illustrator/Presets/Symbols": [.presets],
            "~/Library/Application Support/Adobe/Adobe Illustrator/Presets/Swatches": [.presets],
            "~/Library/Application Support/Adobe/Adobe Illustrator/Presets/Graphic Styles": [.presets],
            "~/Library/Application Support/Adobe/Adobe Illustrator/Presets/Actions": [.presets],
            "~/Library/Application Support/Adobe/Adobe Illustrator/Scripts": [.scripts]
        ],
        
        // Final Cut Pro
        "com.apple.FinalCut": [
            "/Applications/Final Cut Pro.app": [.applications],
            "/Applications/Final Cut Pro.app/Contents/PlugIns": [.plugins],
            "~/Movies/Motion Templates": [.templates],
            "~/Movies/Final Cut Pro/Effects": [.effects],
            "~/Movies/Final Cut Pro/Generators": [.effects],
            "~/Movies/Final Cut Pro/Titles": [.templates],
            "~/Movies/Final Cut Pro/Transitions": [.effects],
            "~/Movies/Final Cut Pro/Themes": [.templates]
        ],
        
        // DaVinci Resolve
        "com.blackmagic-design.DaVinciResolve": [
            "/Applications/DaVinci Resolve/DaVinci Resolve.app": [.applications],
            "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/PlugIns": [.plugins],
            "~/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT": [.presets],
            "~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Templates": [.templates],
            "~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Macros": [.presets],
            "~/Documents/DaVinci Resolve/Effects": [.effects]
        ],
        
        // Cinema 4D
        "net.maxon.cinema4d": [
            "/Applications/Maxon Cinema 4D.app": [.applications],
            "/Applications/Maxon Cinema 4D {YEAR}/Maxon Cinema 4D {YEAR}.app": [.applications],
            "/Applications/Maxon Cinema 4D {YEAR}/plugins": [.plugins],
            "~/Library/Preferences/Maxon/Cinema 4D/library": [.assets],
            "~/Library/Preferences/Maxon/Cinema 4D/presets": [.presets],
            "~/Library/Application Support/Maxon/Cinema 4D/scripts": [.scripts]
        ]
    ]
    
    static let applicationDisplayNames: [String: String] = [
        "com.adobe.AfterEffects": "Adobe After Effects",
        "com.adobe.PremierePro": "Adobe Premiere Pro", 
        "com.adobe.Photoshop": "Adobe Photoshop",
        "com.adobe.Illustrator": "Adobe Illustrator",
        "com.apple.FinalCut": "Final Cut Pro",
        "com.blackmagic-design.DaVinciResolve": "DaVinci Resolve",
        "net.maxon.cinema4d": "Cinema 4D"
    ]
    
    static func getDirectoryConfiguration(for bundleIdentifier: String) -> [String: [DirectoryType]]? {
        return supportedApplications[bundleIdentifier]
    }
    
    static func getSupportedApplications() -> [String] {
        return Array(supportedApplications.keys)
    }
    
    static func getDisplayName(for bundleIdentifier: String) -> String? {
        return applicationDisplayNames[bundleIdentifier]
    }
    
    static func getBundleIdentifier(for displayName: String) -> String? {
        return applicationDisplayNames.first { $0.value == displayName }?.key
    }
    
    static func isSupported(bundleIdentifier: String) -> Bool {
        return supportedApplications[bundleIdentifier] != nil
    }
    
    static func getAvailableApplicationDisplayNames() -> [String] {
        return Array(applicationDisplayNames.values).sorted()
    }
    
}
