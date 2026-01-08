import Foundation
import UniformTypeIdentifiers
import SwiftUI

/// Represents a file or folder in the folder browser with rich metadata
struct FolderBrowserItem: Identifiable {
    let id: UUID
    let url: URL
    let isDirectory: Bool
    let contentType: UTType?
    let fileSize: Int64?
    let creationDate: Date?
    let modificationDate: Date?

    var displayName: String {
        url.lastPathComponent
    }

    var formattedFileSize: String {
        guard let size = fileSize, !isDirectory else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedModificationDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }

        guard let contentType else {
            return "doc"
        }

        // Creative file types
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "psd", "psb":
            return "photo.on.rectangle"
        case "ai", "eps":
            return "pencil.and.outline"
        case "sketch":
            return "paintbrush.pointed"
        case "fig", "figma":
            return "rectangle.on.rectangle"
        case "aep":
            return "film.stack"
        case "prproj":
            return "video.fill"
        case "fcpx", "fcp":
            return "scissors"
        case "c4d", "blend", "ma", "mb", "fbx", "obj":
            return "cube.fill"
        case "ttf", "otf", "woff", "woff2":
            return "textformat"
        default:
            break
        }

        // UTType-based detection
        if contentType.conforms(to: .image) {
            return "photo"
        } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return "video.fill"
        } else if contentType.conforms(to: .audio) {
            return "music.note"
        } else if contentType.conforms(to: .archive) {
            return "archivebox.fill"
        } else if contentType.conforms(to: .pdf) {
            return "doc.richtext"
        } else if contentType.conforms(to: .text) {
            return "doc.text"
        }

        return "doc"
    }

    var iconColor: Color {
        if isDirectory {
            return .accentColor
        }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "psd", "psb", "ai", "eps", "sketch", "fig", "figma":
            return .purple
        case "aep", "prproj", "fcpx", "fcp":
            return .blue
        case "c4d", "blend", "ma", "mb", "fbx", "obj":
            return .orange
        case "ttf", "otf", "woff", "woff2":
            return .green
        default:
            break
        }

        guard let contentType else {
            return .secondary
        }

        if contentType.conforms(to: .image) {
            return .pink
        } else if contentType.conforms(to: .video) || contentType.conforms(to: .movie) {
            return .blue
        } else if contentType.conforms(to: .audio) {
            return .purple
        }

        return .secondary
    }

    init(url: URL) throws {
        self.id = UUID()
        self.url = url

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .contentTypeKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ]

        let values = try url.resourceValues(forKeys: resourceKeys)

        self.isDirectory = values.isDirectory ?? false
        self.contentType = values.contentType
        self.fileSize = values.fileSize.map { Int64($0) }
        self.creationDate = values.creationDate
        self.modificationDate = values.contentModificationDate
    }
}

extension FolderBrowserItem: Comparable {
    static func < (lhs: FolderBrowserItem, rhs: FolderBrowserItem) -> Bool {
        // Directories always come first
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }
        // Then sort alphabetically
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}

extension FolderBrowserItem: Equatable {
    static func == (lhs: FolderBrowserItem, rhs: FolderBrowserItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension FolderBrowserItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
