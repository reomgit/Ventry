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
                        StarredItemRowView(item: item)
                    }
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
                        NavigationLink(
                            destination: FileBrowserView(title: folder.rawValue, path: folder.navigationPath)
                        ) {
                            RegularFolderRowView(folder: folder)
                        }
                    }
                    
                    if !appState.regularFolders.isEmpty && !appState.collections.isEmpty {
                        Divider()
                    }
                    
                    ForEach(appState.collections) { collection in
                        NavigationLink(destination: FolderBrowserView(
                            title: collection.name,
                            path: collection.path
                        )) {
                            CollectionRowView(collection: collection)
                                .contextMenu {
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
                        .contentShape(Rectangle())
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
                        
                        NavigationLink(destination: ApplicationSettingsView()) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Scan for Apps")
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                        .padding(.top, 4)
                    }
                } else {
                    ForEach(appState.applications) { application in
                        NavigationLink(destination: ApplicationDirectoryView(bundleIdentifier: application.bundleIdentifier)) {
                            ApplicationRowView(application: application)
                        }
                        .contextMenu {
                            Button("Remove Application", role: .destructive) {
                                pendingDeleteApplication = application
                                showingDeleteApplicationAlert = true
                            }
                        }
                    }
                    
                    NavigationLink(destination: ApplicationSettingsView()) {
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
        .onAppear {
            appState.refreshZXPInstallerStatus(shouldPrompt: false)
        }
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                zxpInstallerFooter
                    .background(Color(nsColor: .windowBackgroundColor))
            }
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

    private var zxpInstallerFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.isZXPInstallerConnected ? Color.green : Color.secondary.opacity(0.6))
                    .frame(width: 8, height: 8)

                Text(zxpStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button(primaryZXPActionTitle) {
                    handlePrimaryZXPAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .lineLimit(1)

                if appState.isZXPInstallerConnected {
                    Button("Disconnect") {
                        appState.disconnectZXPInstaller()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var zxpStatusText: String {
        if appState.isZXPInstallerConnected {
            return "ZXP Installer connected"
        }

        if appState.isZXPInstallerInstalled {
            return "ZXP Installer detected"
        }

        return "ZXP Installer not installed"
    }

    private var primaryZXPActionTitle: String {
        if appState.isZXPInstallerConnected {
            return "Open ZXP Installer"
        }

        if appState.isZXPInstallerInstalled {
            return "Connect ZXP Installer"
        }

        return "Download ZXP Installer"
    }

    private func handlePrimaryZXPAction() {
        if appState.isZXPInstallerConnected {
            openDetectedZXPInstaller()
            return
        }

        if appState.isZXPInstallerInstalled {
            appState.connectZXPInstaller()
            openDetectedZXPInstaller()
            return
        }

        NSWorkspace.shared.open(appState.zxpInstallerDownloadURL)
    }

    private func openDetectedZXPInstaller() {
        guard let zxpInstallerAppURL = appState.zxpInstallerAppURL else { return }
        _ = NSWorkspace.shared.open(zxpInstallerAppURL)
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
            Image(systemName: item.type.systemImage)
                .foregroundColor(.yellow)
                .font(.title3)
            
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
