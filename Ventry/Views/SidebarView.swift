import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var pendingDeleteApplication: Application? = nil
    @State private var showingDeleteApplicationAlert = false
    
    var body: some View {
        List {
            // Starred Items Section
            Section("Starred") {
                if appState.starredItems.isEmpty {
                    Text("No starred items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(appState.starredItems) { item in
                        sidebarRowButton(selection: .starred(item.id)) {
                            appState.openStarredItem(item)
                        } label: {
                            StarredItemRowView(item: item)
                        }
                        .contextMenu {
                            Button("Open in New Tab") {
                                appState.openStarredItemInNewTab(item)
                            }

                            Divider()

                            Button("Reveal in Finder") {
                                revealStarredItemInFinder(item)
                            }

                            Divider()

                            Button("Remove from Starred", role: .destructive) {
                                try? appState.removeStarredItem(item)
                            }
                        }
                    }
                    .onMove(perform: appState.moveStarredItems)
                }
            }
            
            // Collections Section
            Section("Collections") {
                if appState.regularFolders.isEmpty && appState.collections.isEmpty {
                    Text("No collections available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(appState.regularFolders, id: \.self) { folder in
                        sidebarRowButton(selection: .regularFolder(folder)) {
                            appState.openRegularFolder(folder)
                        } label: {
                            RegularFolderRowView(folder: folder)
                        }
                        .contextMenu {
                            Button("Open in New Tab") {
                                appState.openRegularFolderInNewTab(folder)
                            }
                        }
                    }
                    
                    if !appState.regularFolders.isEmpty && !appState.collections.isEmpty {
                        Divider()
                    }
                    
                    ForEach(appState.collections) { collection in
                        sidebarRowButton(selection: .collection(collection.id)) {
                            appState.openCollection(collection)
                        } label: {
                            CollectionRowView(collection: collection)
                        }
                        .contextMenu {
                            Button("Open in New Tab") {
                                appState.openCollectionInNewTab(collection)
                            }

                            Divider()

                            Button("Refresh Collection") {
                                Task {
                                    await appState.refreshCollection(collection)
                                }
                            }
                            Divider()
                            Button("Remove Collection", role: .destructive) {
                                appState.removeCollection(withId: collection.id)
                            }
                        }
                    }
                }
            }
            
            // Applications Section
            Section("Applications") {
                if appState.applications.isEmpty {
                    VStack {
                        Text("No applications added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                        
                        Button {
                            appState.showApplicationSettings()
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Scan for Apps")
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                } else {
                    ForEach(appState.applications) { application in
                        sidebarRowButton(selection: .application(application.id)) {
                            appState.showApplicationDirectories(application)
                        } label: {
                            ApplicationRowView(application: application)
                        }
                        .contextMenu {
                            Button("Remove Application", role: .destructive) {
                                pendingDeleteApplication = application
                                showingDeleteApplicationAlert = true
                            }
                        }
                    }
                    
                    sidebarRowButton(selection: .applicationSettings) {
                        appState.showApplicationSettings()
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundColor(.secondary)
                            Text("Manage Applications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // User Tags Section
            Section("Tags") {
                if appState.userTags.isEmpty {
                    Text("No tags created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(appState.userTags) { tag in
                        UserTagRowView(tag: tag)
                    }
                }
            }
        }
        .navigationTitle("Library")
        .listStyle(SidebarListStyle())
        .focusEffectDisabled()
        .onKeyPress(.upArrow) {
            return .handled
        }
        .onKeyPress(.downArrow) {
            return .handled
        }
        .onKeyPress(.leftArrow) {
            return .handled
        }
        .onKeyPress(.rightArrow) {
            return .handled
        }
        .alert("Remove App From Ventry?", isPresented: $showingDeleteApplicationAlert, presenting: pendingDeleteApplication) { app in
            Button("Remove App", role: .destructive) {
                appState.removeApplication(app)
                pendingDeleteApplication = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteApplication = nil
            }
        } message: { app in
            Text("This will remove \(app.name) from Ventry and delete all \(app.directories.count) path entr\(app.directories.count == 1 ? "y" : "ies") assigned to it.")
        }
    }

    private func isSelected(_ selection: SidebarSelection) -> Bool {
        appState.selectedSidebarItem == selection
    }

    private func sidebarRowButton<Label: View>(
        selection: SidebarSelection,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected(selection) ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func revealStarredItemInFinder(_ item: StarredItem) {
        guard let path = item.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

struct CollectionRowView: View {
    let collection: Collection
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text("\(collection.assetCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct StarredItemRowView: View {
    let item: StarredItem
    
    var body: some View {
        HStack {
            StarredItemIconView(item: item, size: 18)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                
                if let path = item.path {
                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct StarredItemIconView: View {
    let item: StarredItem
    let size: CGFloat

    var body: some View {
        Image(nsImage: SidebarStarredIconProvider.shared.icon(for: item, pointSize: size))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

@MainActor
private final class SidebarStarredIconProvider {
    static let shared = SidebarStarredIconProvider()

    private let workspace = NSWorkspace.shared
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 256
    }

    func icon(for item: StarredItem, pointSize: CGFloat) -> NSImage {
        let normalizedSize = max(12, Int(pointSize.rounded()))
        let cacheKey = "\(item.path ?? item.id.uuidString)#\(normalizedSize)" as NSString

        if let path = item.path, FileManager.default.fileExists(atPath: path),
           let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let icon = loadIcon(for: item, pointSize: CGFloat(normalizedSize))
        if let path = item.path, FileManager.default.fileExists(atPath: path) {
            cache.setObject(icon, forKey: cacheKey)
        }
        return icon
    }

    private func loadIcon(for item: StarredItem, pointSize: CGFloat) -> NSImage {
        if let path = item.path, FileManager.default.fileExists(atPath: path) {
            let icon = workspace.icon(forFile: path)
            icon.size = NSSize(width: pointSize, height: pointSize)
            return icon
        }

        let fallbackName = item.type.systemImage
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let fallback = NSImage(systemSymbolName: fallbackName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
            ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
        fallback.size = NSSize(width: pointSize, height: pointSize)
        return fallback
    }
}

struct StarredItemDestinationView: View {
    let item: StarredItem

    var body: some View {
        guard let path = item.path, !path.isEmpty else {
            return AnyView(unavailableView(message: "This starred item does not have a valid path."))
        }

        let itemURL = URL(fileURLWithPath: path)
        let pathToBrowse = item.type == .folder ? itemURL.path : itemURL.deletingLastPathComponent().path
        let selectionPath = item.type == .file ? itemURL.path : nil

        return AnyView(
            Group {
                if FileManager.default.fileExists(atPath: pathToBrowse) {
                    FolderBrowserView(
                        title: item.type == .folder ? item.name : itemURL.deletingLastPathComponent().lastPathComponent,
                        path: pathToBrowse,
                        initiallySelectedPath: selectionPath
                    )
                } else {
                    unavailableView(message: "This starred item is no longer available at \(path).")
                }
            }
        )
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Starred Item Unavailable")
                .font(.headline)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RegularFolderRowView: View {
    let folder: RegularFolder
    
    var body: some View {
        HStack {
            Image(systemName: folder.systemImage)
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.rawValue)
                    .font(.body)
                    .lineLimit(1)
                
                Text(folder.defaultPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct ApplicationRowView: View {
    let application: Application

    var body: some View {
        HStack {
            // App icon
            if let bundlePath = application.bundlePath,
               let icon = AppLoader.shared.getAppIcon(for: bundlePath) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(5)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "app.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(application.name)
                    .font(.body)
                    .lineLimit(1)

                Text("\(application.directories.count) directories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct UserTagRowView: View {
    let tag: UserTag
    
    var body: some View {
        HStack {
            Circle()
                .fill(tag.color.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text("\(tag.itemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
