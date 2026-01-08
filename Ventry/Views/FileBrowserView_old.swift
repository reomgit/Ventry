import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct FileBrowserView: View {
    let title: String
    let path: String
    
    @State private var entries: [FileBrowserEntry] = []
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
            } else if entries.isEmpty {
                Text("Folder is empty")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(entries) { entry in
                    if entry.isDirectory {
                        NavigationLink(
                            destination: FileBrowserView(
                                title: entry.displayName,
                                path: entry.url.path
                            )
                        ) {
                            FileBrowserRow(entry: entry)
                        }
                    } else {
                        FileBrowserRow(entry: entry)
                            .contextMenu {
                                #if os(macOS)
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                                }
                                #endif
                            }
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear(perform: loadDirectory)
    }
    
    private func loadDirectory() {
        let directoryURL = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = "The path \"\(path)\" could not be opened."
            entries = []
            return
        }
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            )
            
            let newEntries = try urls.map { url -> FileBrowserEntry in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
                return FileBrowserEntry(
                    url: url,
                    isDirectory: values.isDirectory ?? false,
                    contentType: values.contentType
                )
            }
            
            entries = newEntries.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to read contents of \"\(title)\"."
            entries = []
        }
    }
}

private struct FileBrowserEntry: Identifiable {
    let url: URL
    let isDirectory: Bool
    let contentType: UTType?
    
    var id: URL { url }
    
    var displayName: String {
        url.lastPathComponent
    }
    
    var iconName: String {
        if isDirectory {
            return "folder"
        }
        
        guard let contentType else {
            return "doc"
        }
        
        if contentType.conforms(to: .image) {
            return "photo"
        } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return "video"
        } else if contentType.conforms(to: .audio) {
            return "music.note"
        } else if contentType.conforms(to: .archive) {
            return "archivebox"
        } else if contentType.conforms(to: .pdf) || contentType.conforms(to: .text) {
            return "doc.text"
        }
        
        return "doc"
    }
}

private struct FileBrowserRow: View {
    let entry: FileBrowserEntry
    
    var body: some View {
        HStack {
            Image(systemName: entry.iconName)
                .foregroundColor(entry.isDirectory ? .accentColor : .secondary)
                .frame(width: 20)
            
            Text(entry.displayName)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
