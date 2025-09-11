import SwiftUI
import UniformTypeIdentifiers

struct ApplicationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddDirectory = false
    @State private var selectedApplication: Application?
    @State private var showingApplicationScanner = false
    @State private var showingManualAppSelection = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with scan button
            HStack {
                Text("Applications")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        showingApplicationScanner = true
                    }) {
                        HStack {
                            if appState.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning...")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Scan Apps")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(appState.isScanning)
                    
                    Button(action: {
                        showingManualAppSelection = true
                    }) {
                        HStack {
                            Image(systemName: "plus.app")
                            Text("Add App")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Applications list
            if appState.isLoadingApplications {
                Spacer()
                VStack {
                    ProgressView()
                    Text("Loading applications...")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if appState.applications.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No supported applications found")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Scan for applications or add custom directories")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(appState.applications) { application in
                        SettingsApplicationRowView(
                            application: application,
                            onAddDirectory: {
                                selectedApplication = application
                                showingAddDirectory = true
                            },
                            onRemoveDirectory: { directoryId in
                                appState.removeCustomDirectory(for: application, directoryId: directoryId)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingAddDirectory) {
            if let application = selectedApplication {
                AddDirectoryView(application: application)
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showingApplicationScanner) {
            ApplicationScannerView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingManualAppSelection) {
            ManualAppSelectionView()
                .environmentObject(appState)
        }
    }
}

struct SettingsApplicationRowView: View {
    let application: Application
    let onAddDirectory: () -> Void
    let onRemoveDirectory: (UUID) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Application header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(application.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Directory count badge
                Text("\(application.directories.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(12)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Directories list (when expanded)
            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(application.directories) { directory in
                        SettingsDirectoryRowView(
                            directory: directory,
                            onRemove: {
                                onRemoveDirectory(directory.id)
                            }
                        )
                    }
                    
                    // Add directory button
                    Button(action: onAddDirectory) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Custom Directory")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct SettingsDirectoryRowView: View {
    let directory: AppDirectory
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: directory.type.systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(directory.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(directory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(directory.type.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.secondarySystemFill))
                .cornerRadius(4)
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

struct AddDirectoryView: View {
    let application: Application
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    @State private var directoryName = ""
    @State private var directoryPath = ""
    @State private var selectedType = DirectoryType.other
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Directory Information")) {
                    TextField("Directory Name", text: $directoryName)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(DirectoryType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.systemImage)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    
                    HStack {
                        TextField("Path", text: $directoryPath)
                        
                        Button("Browse") {
                            showingFileImporter = true
                        }
                    }
                }
                
                Section(header: Text("Application")) {
                    Text(application.name)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Directory")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addDirectory()
                    }
                    .disabled(directoryName.isEmpty || directoryPath.isEmpty)
                }
            }
            #endif
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        directoryPath = url.path
                        if directoryName.isEmpty {
                            directoryName = url.lastPathComponent
                        }
                    }
                case .failure(let error):
                    print("File selection error: \(error)")
                }
            }
        }
    }
    
    private func addDirectory() {
        let directory = AppDirectory(
            name: directoryName,
            path: directoryPath,
            type: selectedType
        )
        
        appState.addCustomDirectory(for: application, directory: directory)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ApplicationScannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    @State private var detectedApplications: [DetectedApplication] = []
    @State private var hasScanned = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Text("Scan for Applications")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if hasScanned && !detectedApplications.isEmpty {
                    Button(action: addSelectedApplications) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Add Selected")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(selectedDirectoriesCount == 0)
                } else {
                    // Empty spacer to balance the Cancel button
                    Button("") { }
                        .opacity(0)
                        .disabled(true)
                }
            }
            .padding()
            
            Divider()
            
            if appState.isScanning {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView(value: appState.scanProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: 300)
                    
                    Text("Scanning applications...")
                        .font(.headline)
                    
                    Text("\(Int(appState.scanProgress * 100))% complete")
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else if !hasScanned {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("Find Supported Applications")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Scan your Applications folder for supported applications and select which directories to track.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Button(action: scanApplications) {
                    Text("Start Scan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                Spacer()
            } else if detectedApplications.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Supported Applications Found")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("No applications with configured directory types were found in your Applications folder.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Scan Again") {
                        hasScanned = false
                    }
                    .padding(.top)
                }
                Spacer()
            } else {
                // Applications list with toggleable directories
                List {
                    ForEach($detectedApplications) { $app in
                        DetectedApplicationRowView(detectedApp: $app)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var selectedDirectoriesCount: Int {
        detectedApplications.reduce(0) { total, app in
            total + app.availableDirectories.filter { $0.isSelected }.count
        }
    }
    
    private func scanApplications() {
        Task {
            await performScan()
        }
    }
    
    private func performScan() async {
        detectedApplications = await scanForDetectedApplications()
        await MainActor.run {
            hasScanned = true
        }
    }
    
    private func scanForDetectedApplications() async -> [DetectedApplication] {
        var detected: [DetectedApplication] = []
        let applicationsPath = "/Applications"
        
        do {
            let applicationURLs = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: applicationsPath),
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                (try? url.resourceValues(forKeys: [.isApplicationKey]))?.isApplication == true
            }
            
            for appURL in applicationURLs {
                if let bundleIdentifier = getBundleIdentifier(for: appURL),
                   let directoryConfig = ApplicationDirectoryConfiguration.getDirectoryConfiguration(for: bundleIdentifier) {
                    
                    let appName = appURL.deletingPathExtension().lastPathComponent
                    let availableDirectories = createAvailableDirectories(from: directoryConfig, appName: appName, appURL: appURL)
                    
                    if !availableDirectories.isEmpty {
                        let detectedApp = DetectedApplication(
                            name: appName,
                            bundleIdentifier: bundleIdentifier,
                            availableDirectories: availableDirectories
                        )
                        detected.append(detectedApp)
                    }
                }
            }
        } catch {
            print("Error scanning applications: \(error)")
        }
        
        return detected
    }
    
    private func getBundleIdentifier(for appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        return bundle.bundleIdentifier
    }
    
    private func createAvailableDirectories(from config: [String: [DirectoryType]], appName: String, appURL: URL) -> [AvailableDirectory] {
        var directories: [AvailableDirectory] = []
        
        // Add plugins from the app bundle itself (for versioned Adobe apps)
        let pluginsPath = appURL.appendingPathComponent("Plug-ins")
        if FileManager.default.fileExists(atPath: pluginsPath.path) {
            let availableDir = AvailableDirectory(
                name: "Plug-ins",
                path: pluginsPath.path,
                type: .plugins,
                isSelected: true
            )
            directories.append(availableDir)
        }
        
        // Add configured paths from the configuration
        for (path, types) in config {
            for type in types {
                let expandedPath = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                let directoryName = URL(fileURLWithPath: expandedPath).lastPathComponent
                
                // Check if directory exists
                let directoryExists = FileManager.default.fileExists(atPath: expandedPath)
                
                let availableDir = AvailableDirectory(
                    name: directoryName,
                    path: expandedPath,
                    type: type,
                    isSelected: directoryExists // Only select existing directories by default
                )
                directories.append(availableDir)
            }
        }
        
        return directories
    }
    
    private func addSelectedApplications() {
        for detectedApp in detectedApplications {
            let selectedDirectories = detectedApp.availableDirectories
                .filter { $0.isSelected }
                .map { AppDirectory(name: $0.name, path: $0.path, type: $0.type) }
            
            if !selectedDirectories.isEmpty {
                let application = Application(
                    name: detectedApp.name,
                    bundleIdentifier: detectedApp.bundleIdentifier,
                    directories: selectedDirectories
                )
                
                // Add to app state if not already exists
                if !appState.applications.contains(where: { $0.bundleIdentifier == application.bundleIdentifier }) {
                    appState.applications.append(application)
                }
            }
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Supporting Data Models

struct DetectedApplication: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    var availableDirectories: [AvailableDirectory]
}

struct AvailableDirectory: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: DirectoryType
    var isSelected: Bool
}

// MARK: - Supporting Views

struct DetectedApplicationRowView: View {
    @Binding var detectedApp: DetectedApplication
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Application header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detectedApp.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(detectedApp.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selected count badge
                let selectedCount = detectedApp.availableDirectories.filter { $0.isSelected }.count
                Text("\(selectedCount)/\(detectedApp.availableDirectories.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedCount > 0 ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(selectedCount > 0 ? .accentColor : .secondary)
                    .cornerRadius(12)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Directories list (when expanded)
            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach($detectedApp.availableDirectories) { $directory in
                        AvailableDirectoryRowView(directory: $directory)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct AvailableDirectoryRowView: View {
    @Binding var directory: AvailableDirectory
    
    var body: some View {
        HStack {
            Button(action: {
                directory.isSelected.toggle()
            }) {
                Image(systemName: directory.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(directory.isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Image(systemName: directory.type.systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(directory.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(directory.type.rawValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(directory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            directory.isSelected.toggle()
        }
    }
}

struct ManualAppSelectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingFileImporter = false
    @State private var selectedAppURL: URL?
    @State private var detectedApp: DetectedApplication?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Text("Add Application")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let detectedApp = detectedApp {
                    Button("Add Selected") {
                        addSelectedApplication()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(detectedApp.availableDirectories.filter { $0.isSelected }.isEmpty)
                } else {
                    Button("") { }
                        .opacity(0)
                        .disabled(true)
                }
            }
            .padding()
            
            Divider()
            
            if let detectedApp = detectedApp {
                // Show detected app with selectable directories
                List {
                    DetectedApplicationRowView(detectedApp: .constant(detectedApp))
                }
                .listStyle(PlainListStyle())
            } else {
                // Show app selection interface
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "plus.app.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("Select Application")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose an application (.app) file to add its configured directories to Ventry.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button("Choose Application") {
                        showingFileImporter = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                Spacer()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.applicationBundle],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    processSelectedApp(url: url)
                }
            case .failure(let error):
                errorMessage = "Failed to select application: \(error.localizedDescription)"
            }
        }
    }
    
    private func processSelectedApp(url: URL) {
        selectedAppURL = url
        errorMessage = nil
        
        guard let bundleIdentifier = getBundleIdentifier(for: url) else {
            errorMessage = "Could not read bundle identifier from selected application"
            return
        }
        
        guard let directoryConfig = ApplicationDirectoryConfiguration.getDirectoryConfiguration(for: bundleIdentifier) else {
            errorMessage = "This application is not supported. Only applications with configured directory types can be added."
            return
        }
        
        let appName = url.deletingPathExtension().lastPathComponent
        let availableDirectories = createAvailableDirectories(from: directoryConfig, appName: appName, appURL: url)
        
        if availableDirectories.isEmpty {
            errorMessage = "No configured directories found for this application"
            return
        }
        
        detectedApp = DetectedApplication(
            name: appName,
            bundleIdentifier: bundleIdentifier,
            availableDirectories: availableDirectories
        )
    }
    
    private func getBundleIdentifier(for appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        return bundle.bundleIdentifier
    }
    
    private func createAvailableDirectories(from config: [String: [DirectoryType]], appName: String, appURL: URL) -> [AvailableDirectory] {
        var directories: [AvailableDirectory] = []
        
        // Add plugins from the app bundle itself (for versioned Adobe apps)
        let pluginsPath = appURL.appendingPathComponent("Plug-ins")
        if FileManager.default.fileExists(atPath: pluginsPath.path) {
            let availableDir = AvailableDirectory(
                name: "Plug-ins",
                path: pluginsPath.path,
                type: .plugins,
                isSelected: true
            )
            directories.append(availableDir)
        }
        
        // Add configured paths from the configuration
        for (path, types) in config {
            for type in types {
                let expandedPath = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                let directoryName = URL(fileURLWithPath: expandedPath).lastPathComponent
                
                // Check if directory exists
                let directoryExists = FileManager.default.fileExists(atPath: expandedPath)
                
                let availableDir = AvailableDirectory(
                    name: directoryName,
                    path: expandedPath,
                    type: type,
                    isSelected: directoryExists // Only select existing directories by default
                )
                directories.append(availableDir)
            }
        }
        
        return directories
    }
    
    private func addSelectedApplication() {
        guard let detectedApp = detectedApp else { return }
        
        let selectedDirectories = detectedApp.availableDirectories
            .filter { $0.isSelected }
            .map { AppDirectory(name: $0.name, path: $0.path, type: $0.type) }
        
        if !selectedDirectories.isEmpty {
            let application = Application(
                name: detectedApp.name,
                bundleIdentifier: detectedApp.bundleIdentifier,
                directories: selectedDirectories
            )
            
            // Add to app state if not already exists
            if !appState.applications.contains(where: { $0.bundleIdentifier == application.bundleIdentifier }) {
                appState.applications.append(application)
            }
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    ApplicationSettingsView()
        .environmentObject(AppState())
}