import SwiftUI

/// Example integration showing how to use FolderBrowserView with Ventry's existing components
/// This file demonstrates best practices but is not part of the main app flow

struct FolderBrowserIntegrationExample: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            Text("Example Integration Scenarios")
                .font(.title)

            // Example 1: Browse an application directory
            Example1_ApplicationDirectory()

            // Example 2: Browse a regular folder
            Example2_RegularFolder()

            // Example 3: Browse with custom path
            Example3_CustomPath()
        }
    }
}

// MARK: - Example 1: Application Directory
private struct Example1_ApplicationDirectory: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GroupBox(label: Text("Example 1: Application Directory")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse plugin folders for installed applications")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let app = appState.applications.first,
                   let directory = app.directories.first {

                    NavigationLink(destination: FolderBrowserView(
                        title: "\(app.name) - \(directory.name)",
                        path: directory.path
                    )) {
                        HStack {
                            Image(systemName: directory.type.systemImage)
                            Text("Browse \(app.name) \(directory.name)")
                        }
                    }
                } else {
                    Text("No applications available")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
        }
    }
}

// MARK: - Example 2: Regular Folder
private struct Example2_RegularFolder: View {
    var body: some View {
        GroupBox(label: Text("Example 2: Regular Folder")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse system folders like Fonts, Downloads, etc.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(RegularFolder.allCases, id: \.self) { folder in
                    NavigationLink(destination: FolderBrowserView(
                        title: folder.rawValue,
                        path: folder.defaultPath
                    )) {
                        HStack {
                            Image(systemName: folder.systemImage)
                            Text(folder.rawValue)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Example 3: Custom Path
private struct Example3_CustomPath: View {
    @State private var customPath = ""
    @State private var showingBrowser = false

    var body: some View {
        GroupBox(label: Text("Example 3: Custom Path")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse any custom directory path")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Enter path", text: $customPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse") {
                        showingBrowser = true
                    }
                    .disabled(customPath.isEmpty)
                }
            }
            .padding()
            .background(
                EmptyView()
                    .navigationDestination(isPresented: $showingBrowser) {
                        FolderBrowserView(
                            title: URL(fileURLWithPath: customPath).lastPathComponent,
                            path: customPath
                        )
                    }
            )
        }
    }
}

// MARK: - Advanced Integration Examples

/// Example: Folder browser with selection callback
struct FolderBrowserWithCallback: View {
    let path: String
    let onFilesSelected: ([URL]) -> Void

    @StateObject private var viewModel = FolderBrowserViewModel()
    @State private var hasSelectedFiles = false

    var body: some View {
        VStack {
            FolderBrowserView(title: "Select Files", path: path)

            // Custom action bar
            HStack {
                Text("\(viewModel.selectedItems.count) items selected")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    viewModel.deselectAll()
                }
                .disabled(viewModel.selectedItems.isEmpty)

                Button("Use Selected Files") {
                    let urls = viewModel.selectedItems.map { $0.url }
                    onFilesSelected(urls)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItems.isEmpty)
            }
            .padding()
        }
    }
}

/// Example: Folder browser that scans selected directory
struct FolderBrowserWithScan: View {
    let initialPath: String

    @StateObject private var viewModel = FolderBrowserViewModel()
    @EnvironmentObject var appState: AppState
    @State private var isScanning = false

    var body: some View {
        VStack {
            FolderBrowserView(title: "Browse and Scan", path: initialPath)

            // Scan button
            Button(action: scanCurrentDirectory) {
                if isScanning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                } else {
                    Label("Scan This Folder for Assets", systemImage: "doc.text.magnifyingglass")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning || viewModel.currentDirectory == nil)
            .padding()
        }
    }

    private func scanCurrentDirectory() {
        guard let currentDir = viewModel.currentDirectory else { return }

        isScanning = true

        Task {
            let assets = await DirectoryScanner.shared.scanForAssets(at: currentDir.path)

            await MainActor.run {
                // Ensure we're using real user path, not sandboxed container path
                var realPath = currentDir.path
                if realPath.contains("/Library/Containers/") {
                    // This is a sandboxed path - resolve to real user path
                    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                    if let relativePath = currentDir.path.components(separatedBy: "/Data/").last {
                        realPath = homeDir + "/" + relativePath
                    }
                    print("⚠️ Converted container path to real path: \(realPath)")
                }

                // Create collection with scanned assets and real path
                let collection = Collection(
                    name: currentDir.lastPathComponent,
                    path: realPath,
                    assets: assets
                )

                appState.addCollection(collection)
                isScanning = false

                print("✅ Created collection '\(collection.name)' with path: \(realPath)")
            }
        }
    }
}

/// Example: Folder browser with file type filtering
struct FolderBrowserFiltered: View {
    let path: String
    let allowedExtensions: Set<String> // e.g., ["psd", "ai", "sketch"]

    @StateObject private var viewModel = FolderBrowserViewModel()

    var filteredItems: [FolderBrowserItem] {
        viewModel.items.filter { item in
            item.isDirectory || allowedExtensions.contains(item.url.pathExtension.lowercased())
        }
    }

    var body: some View {
        VStack {
            Text("Showing only: \(allowedExtensions.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)

            // Custom view using filtered items
            List(filteredItems) { item in
                HStack {
                    Image(systemName: item.iconName)
                        .foregroundColor(item.iconColor)
                    Text(item.displayName)
                }
            }
        }
        .onAppear {
            viewModel.navigateTo(url: URL(fileURLWithPath: path))
        }
    }
}

// MARK: - Usage Examples in Comments

/*
 Usage Example 1: Simple Navigation
 ----------------------------------
 NavigationLink(destination: FolderBrowserView(
     title: "My Plugins",
     path: "/Applications/Adobe After Effects 2025/Plug-ins"
 )) {
     Text("Browse Plugins")
 }


 Usage Example 2: With EnvironmentObject
 ----------------------------------------
 struct ContentView: View {
     @StateObject var appState = AppState()

     var body: some View {
         NavigationView {
             FolderBrowserView(
                 title: "Documents",
                 path: NSHomeDirectory() + "/Documents"
             )
             .environmentObject(appState)
         }
     }
 }


 Usage Example 3: Programmatic Navigation
 -----------------------------------------
 struct MyView: View {
     @State private var showBrowser = false

     var body: some View {
         Button("Open Browser") {
             showBrowser = true
         }
         .sheet(isPresented: $showBrowser) {
             NavigationView {
                 FolderBrowserView(
                     title: "Choose Files",
                     path: "/Applications"
                 )
             }
         }
     }
 }


 Usage Example 4: With Custom Actions
 -------------------------------------
 FolderBrowserView(title: "Assets", path: "/path/to/assets")
     .toolbar {
         ToolbarItem(placement: .primaryAction) {
             Button("Import Selected") {
                 // Custom import logic
             }
         }
     }


 Usage Example 5: Replacing Old FileBrowserView
 -----------------------------------------------
 // Old code:
 FileBrowserView(title: directory.name, path: directory.path)

 // New code (same API, enhanced functionality):
 FileBrowserView(title: directory.name, path: directory.path)

 // Or use directly:
 FolderBrowserView(title: directory.name, path: directory.path)
 */

