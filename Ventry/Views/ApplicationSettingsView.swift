import SwiftUI
import UniformTypeIdentifiers

struct ApplicationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddDirectory = false
    @State private var selectedApplication: Application?
    @State private var showingApplicationScanner = false
    @State private var showingMultipleAppSelection = false
    
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
                    .buttonStyle(PlainButtonStyle())
                    .disabled(appState.isScanning)
                    
                    Button(action: {
                        showingMultipleAppSelection = true
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
                    .buttonStyle(PlainButtonStyle())
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
                    Text("No applications found")
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
        .sheet(isPresented: $showingMultipleAppSelection) {
            ManualMultipleAppSelectionView()
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
                .buttonStyle(PlainButtonStyle())
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
                    .buttonStyle(PlainButtonStyle())
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text("Add Custom Directory")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Add") {
                    addDirectory()
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(directoryName.isEmpty || directoryPath.isEmpty)
            }
            .padding()

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Directory Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Directory Information")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directory Name")
                                .font(.subheadline)
                            TextField("Enter directory name", text: $directoryName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.subheadline)
                            Picker("Type", selection: $selectedType) {
                                ForEach(DirectoryType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.systemImage)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directory Path")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                TextField("Enter or browse for path", text: $directoryPath)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button("Browse...") {
                                    showingFileImporter = true
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    // Application Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Application")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(application.name)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding()
            }
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
        .frame(minWidth: 550, idealWidth: 600, maxWidth: 700, minHeight: 450, idealHeight: 500, maxHeight: 600)
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
    @State private var selectedAppBundles: Set<String> = []
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }

                Spacer()

                Text("Applications")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                if !detectedApplications.isEmpty {
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
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedDirectoriesCount == 0)
                } else {
                    // Empty spacer to balance the Cancel button
                    Button("") { }
                        .opacity(0)
                        .disabled(true)
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()

            Divider()

            if appState.isLoadingApps {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Loading applications...")
                        .font(.headline)
                }
                .padding()
                Spacer()
            } else if appState.loadedApps.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Applications Found")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("No applications were found in your Applications folder.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                Spacer()
            } else if detectedApplications.isEmpty {
                // Show only supported apps
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Found \(supportedAppsCount) supported application\(supportedAppsCount == 1 ? "" : "s")")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top)

                        Text("Select applications to scan their directories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        // Filter options
                        HStack {
                            Button(action: {
                                if selectedAppBundles.count == supportedAppsCount {
                                    selectedAppBundles.removeAll()
                                } else {
                                    selectedAppBundles = Set(supportedApps.map { $0.bundlePath })
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedAppBundles.count == supportedAppsCount ? "checkmark.square.fill" : "square")
                                    Text("Select All (\(supportedAppsCount))")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)

                            Spacer()

                            if selectedAppBundles.count > 0 {
                                Button(action: scanSelectedApplications) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Add \(selectedAppBundles.count) App\(selectedAppBundles.count == 1 ? "" : "s")")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)

                        Divider()

                        // Only show supported applications
                        LazyVStack(spacing: 8) {
                            ForEach(supportedApps) { app in
                                LoadedAppRow(
                                    app: app,
                                    isSelected: selectedAppBundles.contains(app.bundlePath),
                                    onToggle: {
                                        if selectedAppBundles.contains(app.bundlePath) {
                                            selectedAppBundles.remove(app.bundlePath)
                                        } else {
                                            selectedAppBundles.insert(app.bundlePath)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                // Show scanned applications with directory toggles
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

    private var supportedApps: [AppLoader.LoadedApp] {
        appState.loadedApps.filter { $0.isSupported }
    }

    private var supportedAppsCount: Int {
        supportedApps.count
    }
    
    private var selectedDirectoriesCount: Int {
        detectedApplications.reduce(0) { total, app in
            total + app.availableDirectories.filter { $0.isSelected }.count
        }
    }

    private func scanSelectedApplications() {
        Task {
            await performScan()
        }
    }

    private func performScan() async {
        await MainActor.run {
            isScanning = true
        }

        var detected: [DetectedApplication] = []

        // Get selected apps
        let selectedApps = appState.loadedApps.filter { selectedAppBundles.contains($0.bundlePath) }

        for loadedApp in selectedApps where loadedApp.isSupported {
            if let bundleIdentifier = loadedApp.bundleIdentifier,
               let supportedApp = appState.applicationManagerAccess.getSupportedApplication(for: bundleIdentifier) {

                let appURL = URL(fileURLWithPath: loadedApp.bundlePath)
                let availableDirectories = createAvailableDirectories(from: supportedApp, appName: loadedApp.name, appURL: appURL)

                if !availableDirectories.isEmpty {
                    let detectedApp = DetectedApplication(
                        name: loadedApp.name,
                        bundleIdentifier: bundleIdentifier,
                        availableDirectories: availableDirectories
                    )
                    detected.append(detectedApp)
                }
            }
        }

        await MainActor.run {
            self.detectedApplications = detected
            self.isScanning = false
        }
    }
    
    private func createAvailableDirectories(from supportedApp: SupportedApplication, appName: String, appURL: URL) -> [AvailableDirectory] {
        var directories: [AvailableDirectory] = []

        // Add paths from the configuration
        for supportedPath in supportedApp.paths {
            var expandedPath = supportedPath.path

            // Handle Adobe year-based paths
            if expandedPath.contains("{year}") {
                let currentYear = Calendar.current.component(.year, from: Date())
                expandedPath = expandedPath.replacingOccurrences(of: "{year}", with: String(currentYear))
            }

            // Expand home directory
            expandedPath = expandedPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

            // Check if directory exists
            let directoryExists = FileManager.default.fileExists(atPath: expandedPath)

            let directoryType = DirectoryType(rawValue: supportedPath.type) ?? .other

            let availableDir = AvailableDirectory(
                name: supportedPath.name,
                path: expandedPath,
                type: directoryType,
                isSelected: directoryExists // Only select existing directories by default
            )
            directories.append(availableDir)
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
// Models are now defined in InstallationModels.swift

// MARK: - Supporting Views

struct DetectedApplicationRowView: View {
    @Binding var detectedApp: DetectedApplication
    @State private var isExpanded = true
    @State private var showingAddCustomPath = false

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
                .buttonStyle(PlainButtonStyle())
            }

            // Directories list (when expanded)
            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach($detectedApp.availableDirectories) { $directory in
                        AvailableDirectoryRowView(directory: $directory)
                    }

                    // Add Custom Path button
                    Button(action: {
                        showingAddCustomPath = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Custom Path")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .sheet(isPresented: $showingAddCustomPath) {
            AddCustomPathToDetectedAppView(
                detectedApp: $detectedApp,
                onComplete: {
                    showingAddCustomPath = false
                }
            )
        }
    }
}

// AvailableDirectoryRowView is now defined in InstallationModels.swift


struct ManualMultipleAppSelectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedAppURLs: [URL] = []
    @State private var showingFileImporter = true
    @State private var detectedApps: [DetectedApplication] = []
    @State private var showingInstallationFlow = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }

                Spacer()

                Text("Add Applications")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                if !detectedApps.isEmpty {
                    Button("Install All") {
                        showingInstallationFlow = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("") { }
                        .opacity(0)
                        .disabled(true)
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()

            Divider()

            if detectedApps.isEmpty && !showingFileImporter {
                // Show app selection interface if file importer was cancelled
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)

                    Text("Select Applications")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Choose application (.app) files to configure and add them to Ventry.")
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

                    Button("Choose Applications") {
                        showingFileImporter = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            } else if !detectedApps.isEmpty {
                // Show selected apps list
                VStack(alignment: .leading, spacing: 16) {
                    Text("Selected Applications (\(detectedApps.count))")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    List {
                        ForEach(detectedApps) { app in
                            MultipleAppRowView(
                                detectedApp: app,
                                isSupported: appState.applicationManagerAccess.isApplicationSupported(app.bundleIdentifier),
                                onRemove: {
                                    removeApp(app)
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())

                    HStack {
                        Button("Add More Apps") {
                            showingFileImporter = true
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.applicationBundle],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                processSelectedApps(urls: urls)
            case .failure(let error):
                // Check if user cancelled
                if error.localizedDescription.contains("cancelled") || error.localizedDescription.contains("canceled") {
                    if detectedApps.isEmpty {
                        // If user cancelled and no apps selected, dismiss the view
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    errorMessage = "Failed to select applications: \(error.localizedDescription)"
                }
            }
        }
        .sheet(isPresented: $showingInstallationFlow) {
            ApplicationInstallationFlowView(
                detectedApps: detectedApps,
                supportedApps: appState.applicationManagerAccess.supportedApplications,
                onComplete: { installedApps in
                    // Add installed apps to app state
                    for app in installedApps {
                        if !appState.applications.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                            appState.applications.append(app)
                        }
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func processSelectedApps(urls: [URL]) {
        errorMessage = nil
        var newDetectedApps: [DetectedApplication] = []

        for url in urls {
            guard let bundleIdentifier = getBundleIdentifier(for: url) else {
                errorMessage = "Could not read bundle identifier from \(url.lastPathComponent)"
                continue
            }

            // Skip if already added
            if detectedApps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
                continue
            }

            let appName = url.deletingPathExtension().lastPathComponent

            // Check if app is supported and create available directories
            var availableDirectories: [AvailableDirectory] = []
            if let supportedApp = appState.applicationManagerAccess.getSupportedApplication(for: bundleIdentifier) {
                availableDirectories = createAvailableDirectories(from: supportedApp, appName: appName, appURL: url)
            }

            let detectedApp = DetectedApplication(
                name: appName,
                bundleIdentifier: bundleIdentifier,
                availableDirectories: availableDirectories
            )
            newDetectedApps.append(detectedApp)
        }

        detectedApps.append(contentsOf: newDetectedApps)
    }

    private func removeApp(_ app: DetectedApplication) {
        detectedApps.removeAll { $0.id == app.id }
    }

    private func getBundleIdentifier(for appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        return bundle.bundleIdentifier
    }

    private func createAvailableDirectories(from supportedApp: SupportedApplication, appName: String, appURL: URL) -> [AvailableDirectory] {
        var directories: [AvailableDirectory] = []

        for supportedPath in supportedApp.paths {
            var expandedPath = supportedPath.path

            // Handle Adobe year-based paths
            if expandedPath.contains("{year}") {
                let currentYear = Calendar.current.component(.year, from: Date())
                expandedPath = expandedPath.replacingOccurrences(of: "{year}", with: String(currentYear))
            }

            // Expand home directory
            expandedPath = expandedPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

            // Check if directory exists
            let directoryExists = FileManager.default.fileExists(atPath: expandedPath)
            let directoryType = DirectoryType(rawValue: supportedPath.type) ?? .other

            let availableDir = AvailableDirectory(
                name: supportedPath.name,
                path: expandedPath,
                type: directoryType,
                isSelected: directoryExists
            )
            directories.append(availableDir)
        }

        return directories
    }
}

struct MultipleAppRowView: View {
    let detectedApp: DetectedApplication
    let isSupported: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSupported ? "app.badge.checkmark" : "app.badge.questionmark")
                .font(.title2)
                .foregroundColor(isSupported ? .accentColor : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(detectedApp.name)
                    .font(.headline)
                    .fontWeight(.medium)

                HStack {
                    Text(isSupported ? "Supported" : "Unsupported")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSupported ? Color.accentColor.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(isSupported ? .accentColor : .orange)
                        .cornerRadius(4)

                    if isSupported {
                        Text("(\(detectedApp.availableDirectories.count) paths)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(detectedApp.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - LoadedAppRow View
struct LoadedAppRow: View {
    let app: AppLoader.LoadedApp
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                // App icon
                if let icon = AppLoader.shared.getAppIcon(for: app.bundlePath) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "app")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.secondary)
                }

                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let bundleID = app.bundleIdentifier {
                        Text(bundleID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Custom Path to Detected App View
struct AddCustomPathToDetectedAppView: View {
    @Binding var detectedApp: DetectedApplication
    let onComplete: () -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var directoryName = ""
    @State private var directoryPath = ""
    @State private var selectedType = DirectoryType.other
    @State private var showingFileImporter = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                VStack(spacing: 4) {
                    Text("Add Custom Path")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("for \(detectedApp.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Add") {
                    addCustomPath()
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(directoryName.isEmpty || directoryPath.isEmpty)
            }
            .padding()

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Directory Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Directory Information")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directory Name")
                                .font(.subheadline)
                            TextField("Enter directory name", text: $directoryName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.subheadline)
                            Picker("Type", selection: $selectedType) {
                                ForEach(DirectoryType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.systemImage)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directory Path")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                TextField("Enter or browse for path", text: $directoryPath)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button("Browse...") {
                                    showingFileImporter = true
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    // Application Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Application")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(detectedApp.name)
                                .font(.body)
                            Text(detectedApp.bundleIdentifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding()
            }
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
        .frame(minWidth: 550, idealWidth: 600, maxWidth: 700, minHeight: 450, idealHeight: 500, maxHeight: 600)
    }

    private func addCustomPath() {
        let newDirectory = AvailableDirectory(
            name: directoryName,
            path: directoryPath,
            type: selectedType,
            isSelected: true
        )

        detectedApp.availableDirectories.append(newDirectory)
        onComplete()
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    ApplicationSettingsView()
        .environmentObject(AppState())
}
