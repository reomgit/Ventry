import Foundation
import AppKit
import UniformTypeIdentifiers

enum FolderBrowserCreativeBadge: Hashable {
    case photoshop
    case illustrator
    case sketch
    case figma
    case afterEffects
    case premiere
    case finalCut
    case threeD
    case font

    var label: String {
        switch self {
        case .photoshop:
            return "PS"
        case .illustrator:
            return "AI"
        case .sketch:
            return "SK"
        case .figma:
            return "FG"
        case .afterEffects:
            return "AE"
        case .premiere:
            return "PR"
        case .finalCut:
            return "FC"
        case .threeD:
            return "3D"
        case .font:
            return "F"
        }
    }

    var color: NSColor {
        switch self {
        case .photoshop:
            return NSColor.systemBlue
        case .illustrator:
            return NSColor.systemOrange
        case .sketch:
            return NSColor.systemOrange
        case .figma:
            return NSColor.systemPurple
        case .afterEffects:
            return NSColor.systemIndigo
        case .premiere:
            return NSColor.systemPurple
        case .finalCut:
            return NSColor.systemRed
        case .threeD:
            return NSColor.systemTeal
        case .font:
            return NSColor.systemGreen
        }
    }

    static func from(pathExtension: String) -> FolderBrowserCreativeBadge? {
        switch pathExtension.lowercased() {
        case "psd", "psb":
            return .photoshop
        case "ai", "eps":
            return .illustrator
        case "sketch":
            return .sketch
        case "fig", "figma":
            return .figma
        case "aep":
            return .afterEffects
        case "prproj":
            return .premiere
        case "fcpx", "fcp":
            return .finalCut
        case "c4d", "blend", "ma", "mb", "fbx", "obj":
            return .threeD
        case "ttf", "otf", "woff", "woff2":
            return .font
        default:
            return nil
        }
    }
}

@MainActor
final class FolderBrowserIconProvider {
    static let shared = FolderBrowserIconProvider()

    private let workspace: NSWorkspace
    private let cache = NSCache<NSString, NSImage>()

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        cache.countLimit = 2048
    }

    func icon(for item: FolderBrowserItem, pointSize: CGFloat) -> NSImage {
        let normalizedSize = max(12, Int(pointSize.rounded()))
        let standardizedPath = item.url.standardizedFileURL.path
        let key = "\(standardizedPath)#\(normalizedSize)" as NSString

        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let icon = loadNativeIcon(for: item, pointSize: CGFloat(normalizedSize))
        cache.setObject(icon, forKey: key)
        return icon
    }

    func badge(for item: FolderBrowserItem) -> FolderBrowserCreativeBadge? {
        guard !item.isDirectory else { return nil }
        return FolderBrowserCreativeBadge.from(pathExtension: item.url.pathExtension)
    }

    private func loadNativeIcon(for item: FolderBrowserItem, pointSize: CGFloat) -> NSImage {
        let pathIcon = workspace.icon(forFile: item.url.path)
        if isUsable(pathIcon) {
            return resizedCopy(of: pathIcon, pointSize: pointSize)
        }

        let typeIcon = workspace.icon(for: fallbackContentType(for: item))
        if isUsable(typeIcon) {
            return resizedCopy(of: typeIcon, pointSize: pointSize)
        }

        let symbol = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let fallback = NSImage(systemSymbolName: item.iconName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbol)
            ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
        fallback.size = NSSize(width: pointSize, height: pointSize)
        return fallback
    }

    private func fallbackContentType(for item: FolderBrowserItem) -> UTType {
        if item.isDirectory {
            return .folder
        }

        if let contentType = item.contentType {
            return contentType
        }

        let ext = item.url.pathExtension
        if !ext.isEmpty, let typeFromExtension = UTType(filenameExtension: ext) {
            return typeFromExtension
        }

        return .data
    }

    private func resizedCopy(of image: NSImage, pointSize: CGFloat) -> NSImage {
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: pointSize, height: pointSize)
        return copy
    }

    private func isUsable(_ image: NSImage) -> Bool {
        image.size.width > 0 && image.size.height > 0
    }
}
