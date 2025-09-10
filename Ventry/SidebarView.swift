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
                ForEach(appState.regularFolders, id: \.self) { folder in
                    RegularFolderRowView(folder: folder)
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
            
            // Software Directories Section
            if !appState.applications.isEmpty {
                ForEach(appState.applications) { application in
                    Section("\(application.name) - Directories") {
                        ForEach(application.directories) { directory in
                            DirectoryRowView(directory: directory)
                        }
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
    }
}

struct ApplicationRowView: View {
    let application: Application
    
    var body: some View {
        HStack {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "app.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                )
            
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
    }
}

struct DirectoryRowView: View {
    let directory: AppDirectory
    @EnvironmentObject var appState: AppState
    @State private var showingCreateCollection = false
    
    var body: some View {
        HStack {
            Image(systemName: directory.type.systemImage)
                .foregroundColor(.secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(directory.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text(directory.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                createCollectionFromDirectory()
            }) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Create collection from this directory")
        }
        .padding(.vertical, 2)
        .alert("Creating Collection", isPresented: $showingCreateCollection) {
            // Alert will be dismissed automatically
        } message: {
            Text("Scanning directory to create collection...")
        }
    }
    
    private func createCollectionFromDirectory() {
        showingCreateCollection = true
        
        DirectoryScanner.shared.createCollectionFromDirectory(directory) { collection in
            appState.addCollection(collection)
            showingCreateCollection = false
        }
    }
}
