import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
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
                        NavigationLink(destination: FileBrowserView(title: folder.rawValue, path: folder.defaultPath)) {
                            RegularFolderRowView(folder: folder)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            folder.ensureDirectoryExists()
                        })
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
                        }
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
                        NavigationLink(destination: ApplicationDirectoryView(application: application)) {
                            ApplicationRowView(application: application)
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
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
