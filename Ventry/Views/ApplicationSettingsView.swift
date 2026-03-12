import SwiftUI
import UniformTypeIdentifiers

struct ApplicationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedApplication: Application?
    @State private var showingApplicationScanner = false
    @State private var showingMultipleAppSelection = false
    @State private var pendingRemoveApp: Application? = nil
    @State private var showingRemoveAppAlert = false
    @State private var pendingDeleteApp: Application? = nil
    @State private var showingDeleteAppAlert = false
    
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
                            Text("Add Custom App")
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
                            },
                            onRemoveDirectory: { directoryId in
                                appState.removeCustomDirectory(for: application, directoryId: directoryId)

                                if application.directories.count == 1 {
                                    pendingRemoveApp = application
                                    showingRemoveAppAlert = true
                                }
                            },
                            onUpdateDirectory: { updatedDirectory in
                                appState.updateCustomDirectory(for: application, directory: updatedDirectory)
                            },
                            onDeleteApplication: {
                                pendingDeleteApp = application
                                showingDeleteAppAlert = true
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(item: $selectedApplication) { application in
            AddDirectoryView(application: application)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingApplicationScanner) {
            ApplicationScannerView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingMultipleAppSelection) {
            ManualMultipleAppSelectionView()
                .environmentObject(appState)
        }
        .alert("Remove App From Ventry?", isPresented: $showingRemoveAppAlert, presenting: pendingRemoveApp) { app in
            Button("Remove App", role: .destructive) {
                appState.removeApplication(app)
                pendingRemoveApp = nil
            }
            Button("Keep App", role: .cancel) {
                pendingRemoveApp = nil
            }
        } message: { app in
            Text("You removed the last path for \(app.name). Do you want to remove the app from Ventry as well?")
        }
        .alert("Remove App From Ventry?", isPresented: $showingDeleteAppAlert, presenting: pendingDeleteApp) { app in
            Button("Remove App", role: .destructive) {
                appState.removeApplication(app)
                pendingDeleteApp = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteApp = nil
            }
        } message: { app in
            Text("This will remove \(app.name) from Ventry and delete all \(app.directories.count) path entr\(app.directories.count == 1 ? "y" : "ies") assigned to it.")
        }
    }
}

struct SettingsApplicationRowView: View {
    let application: Application
    let onAddDirectory: () -> Void
    let onRemoveDirectory: (UUID) -> Void
    let onUpdateDirectory: (AppDirectory) -> Void
    let onDeleteApplication: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Application header
            HStack {
                // App icon
                if let bundlePath = application.bundlePath,
                   let icon = AppLoader.shared.getAppIcon(for: bundlePath) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "app")
                        .font(.title)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.secondary)
                }

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

                Button(role: .destructive, action: onDeleteApplication) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
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
                            onUpdate: onUpdateDirectory,
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
        .contextMenu {
            Button("Remove Application", role: .destructive) {
                onDeleteApplication()
            }
        }
    }
}

struct SettingsDirectoryRowView: View {
    let directory: AppDirectory
    let onUpdate: (AppDirectory) -> Void
    let onRemove: () -> Void

    @State private var showingEditDirectory = false
    
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

            Button {
                showingEditDirectory = true
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditDirectory) {
            EditDirectoryView(
                directory: directory,
                onSave: { updatedDirectory in
                    onUpdate(updatedDirectory)
                    showingEditDirectory = false
                }
            )
        }
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
        .background(Color(.windowBackgroundColor))
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

struct EditDirectoryView: View {
    let directory: AppDirectory
    let onSave: (AppDirectory) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var directoryName: String
    @State private var directoryPath: String
    @State private var selectedType: DirectoryType
    @State private var showingFileImporter = false

    init(directory: AppDirectory, onSave: @escaping (AppDirectory) -> Void) {
        self.directory = directory
        self.onSave = onSave
        _directoryName = State(initialValue: directory.name)
        _directoryPath = State(initialValue: directory.path)
        _selectedType = State(initialValue: directory.type)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text("Edit Directory")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Save") {
                    saveDirectory()
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(directoryName.isEmpty || directoryPath.isEmpty)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
        .background(Color(.windowBackgroundColor))
        .frame(minWidth: 550, idealWidth: 600, maxWidth: 700, minHeight: 450, idealHeight: 500, maxHeight: 600)
    }

    private func saveDirectory() {
        let updatedDirectory = AppDirectory(
            id: directory.id,
            name: directoryName,
            path: directoryPath,
            type: selectedType
        )

        onSave(updatedDirectory)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ApplicationScannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    @State private var detectedApplications: [DetectedApplication] = []
    @State private var selectedInstallKeys: Set<String> = []
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Found \(supportedAppsCount) supported application\(supportedAppsCount == 1 ? "" : "s")")
                                .font(.headline)

                            if alreadyAddedSupportedAppsCount > 0 {
                                Text("\(alreadyAddedSupportedAppsCount) already added")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        Text("Select applications to scan their directories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        // Filter options
                        HStack {
                            Button(action: {
                                if selectedSelectableAppsCount == selectableSupportedAppsCount {
                                    selectedInstallKeys.removeAll()
                                } else {
                                    selectedInstallKeys = Set(selectableSupportedApps.map { $0.installKey })
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedSelectableAppsCount == selectableSupportedAppsCount ? "checkmark.square.fill" : "square")
                                    Text("Select All (\(selectableSupportedAppsCount))")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(selectableSupportedAppsCount == 0)
                            .padding(.horizontal)

                            Spacer()

                            if selectedSelectableAppsCount > 0 {
                                Button(action: scanSelectedApplications) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Add \(selectedSelectableAppsCount) App\(selectedSelectableAppsCount == 1 ? "" : "s")")
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
                        LazyVStack(spacing: 12) {
                            ForEach(supportedAppGroups) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    if group.apps.count > 1 {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(group.displayName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)

                                                Text(group.bundleIdentifier)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Text("\(group.apps.count) installs")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accentColor.opacity(0.15))
                                                .foregroundColor(.accentColor)
                                                .cornerRadius(10)
                                        }
                                    }

                                    ForEach(group.apps) { app in
                                        LoadedAppRow(
                                            app: app,
                                            isSelected: selectedInstallKeys.contains(app.installKey),
                                            isAlreadyAdded: isAppAlreadyAdded(app),
                                            onToggle: {
                                                if selectedInstallKeys.contains(app.installKey) {
                                                    selectedInstallKeys.remove(app.installKey)
                                                } else {
                                                    selectedInstallKeys.insert(app.installKey)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(group.apps.count > 1 ? 10 : 0)
                                .background(group.apps.count > 1 ? Color(.controlBackgroundColor).opacity(0.4) : Color.clear)
                                .cornerRadius(10)
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

    private struct SupportedAppGroup: Identifiable {
        let id: String
        let displayName: String
        let bundleIdentifier: String
        let apps: [AppLoader.LoadedApp]
    }

    private var supportedApps: [AppLoader.LoadedApp] {
        appState.loadedApps.filter { $0.isSupported }
    }

    private var supportedAppGroups: [SupportedAppGroup] {
        let grouped = Dictionary(grouping: supportedApps) { app in
            app.bundleIdentifier ?? app.bundlePath
        }

        return grouped.compactMap { key, apps in
            guard let firstApp = apps.first else {
                return nil
            }

            let bundleIdentifier = firstApp.bundleIdentifier ?? key
            let displayName = appState.applicationManagerAccess.getSupportedApplication(for: bundleIdentifier)?.displayName ?? firstApp.name
            let sortedApps = apps.sorted { left, right in
                let versionOrder = SupportedPathResolver.compareVersionStrings(left.version, right.version)
                if versionOrder != .orderedSame {
                    return versionOrder == .orderedDescending
                }
                return left.bundlePath.localizedStandardCompare(right.bundlePath) == .orderedAscending
            }

            return SupportedAppGroup(
                id: key,
                displayName: displayName,
                bundleIdentifier: bundleIdentifier,
                apps: sortedApps
            )
        }
        .sorted { left, right in
            left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
        }
    }

    private var supportedAppsCount: Int {
        supportedApps.count
    }

    private var selectableSupportedApps: [AppLoader.LoadedApp] {
        supportedApps.filter { !isAppAlreadyAdded($0) }
    }

    private var selectableSupportedAppsCount: Int {
        selectableSupportedApps.count
    }

    private var selectedSelectableAppsCount: Int {
        selectableSupportedApps.filter { selectedInstallKeys.contains($0.installKey) }.count
    }

    private var alreadyAddedSupportedAppsCount: Int {
        supportedAppsCount - selectableSupportedAppsCount
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
        let selectedApps = appState.loadedApps.filter {
            selectedInstallKeys.contains($0.installKey) && !isAppAlreadyAdded($0)
        }

        for loadedApp in selectedApps where loadedApp.isSupported {
            if let bundleIdentifier = loadedApp.bundleIdentifier,
               let supportedApp = appState.applicationManagerAccess.getSupportedApplication(for: bundleIdentifier) {

                let availableDirectories = createAvailableDirectories(
                    from: supportedApp,
                    appVersion: loadedApp.version
                )

                if !availableDirectories.isEmpty {
                    let detectedApp = DetectedApplication(
                        name: loadedApp.name,
                        bundleIdentifier: bundleIdentifier,
                        bundlePath: loadedApp.bundlePath,
                        appVersion: loadedApp.version,
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

    private func isAppAlreadyAdded(_ app: AppLoader.LoadedApp) -> Bool {
        appState.applications.contains { $0.installKey == app.installKey }
    }
    
    private func createAvailableDirectories(from supportedApp: SupportedApplication, appVersion: String?) -> [AvailableDirectory] {
        SupportedPathResolver.resolveDirectories(for: supportedApp, appVersion: appVersion).map { resolvedDirectory in
            AvailableDirectory(
                name: resolvedDirectory.name,
                path: resolvedDirectory.path,
                type: resolvedDirectory.type,
                isSelected: resolvedDirectory.exists
            )
        }
    }

    private func addSelectedApplications() {
        for detectedApp in detectedApplications {
            if detectedApp.isAlreadyAdded {
                continue
            }

            let selectedDirectories = detectedApp.availableDirectories
                .filter { $0.isSelected }
                .map { AppDirectory(name: $0.name, path: $0.path, type: $0.type) }

            if !selectedDirectories.isEmpty {
                let application = Application(
                    name: detectedApp.name,
                    bundleIdentifier: detectedApp.bundleIdentifier,
                    bundlePath: detectedApp.bundlePath,
                    directories: selectedDirectories
                )

                // Add to app state if not already exists
                if !appState.applications.contains(where: { $0.installKey == application.installKey }) {
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
                // App icon
                if let icon = AppLoader.shared.getAppIcon(for: detectedApp.bundlePath) {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(detectedApp.name)
                        .font(.headline)
                        .fontWeight(.medium)

                    Text(detectedApp.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let appVersion = detectedApp.appVersion {
                        Text("Version \(appVersion)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(detectedApp.bundlePath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                    .disabled(installableDetectedApps.isEmpty)
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

                    if alreadyAddedDetectedAppsCount > 0 {
                        Text("\(alreadyAddedDetectedAppsCount) already added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

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
                detectedApps: installableDetectedApps,
                supportedApps: appState.applicationManagerAccess.supportedApplications,
                onComplete: { installedApps in
                    // Add installed apps to app state
                    for app in installedApps {
                        if !appState.applications.contains(where: { $0.installKey == app.installKey }) {
                            appState.applications.append(app)
                        }
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private var installableDetectedApps: [DetectedApplication] {
        detectedApps.filter { !$0.isAlreadyAdded }
    }

    private var alreadyAddedDetectedAppsCount: Int {
        detectedApps.filter { $0.isAlreadyAdded }.count
    }

    private func processSelectedApps(urls: [URL]) {
        errorMessage = nil
        var newDetectedApps: [DetectedApplication] = []
        var existingInstallKeys = Set(detectedApps.map(\.installKey))

        for url in urls {
            guard let metadata = getBundleMetadata(for: url) else {
                errorMessage = "Could not read bundle identifier from \(url.lastPathComponent)"
                continue
            }

            let bundleIdentifier = metadata.bundleIdentifier
            let installKey = "\(bundleIdentifier)::\(url.path)"

            // Skip if already added to the detected list
            if existingInstallKeys.contains(installKey) {
                continue
            }
            existingInstallKeys.insert(installKey)

            let isAlreadyAdded = appState.applications.contains { $0.installKey == installKey }

            let appName = url.deletingPathExtension().lastPathComponent

            // Check if app is supported and create available directories
            var availableDirectories: [AvailableDirectory] = []
            if !isAlreadyAdded,
               let supportedApp = appState.applicationManagerAccess.getSupportedApplication(for: bundleIdentifier) {
                availableDirectories = createAvailableDirectories(from: supportedApp, appVersion: metadata.version)
            }

            let detectedApp = DetectedApplication(
                name: appName,
                bundleIdentifier: bundleIdentifier,
                bundlePath: url.path,
                appVersion: metadata.version,
                availableDirectories: availableDirectories,
                isAlreadyAdded: isAlreadyAdded
            )
            newDetectedApps.append(detectedApp)
        }

        detectedApps.append(contentsOf: newDetectedApps)
    }

    private func removeApp(_ app: DetectedApplication) {
        detectedApps.removeAll { $0.id == app.id }
    }

    private func getBundleMetadata(for appURL: URL) -> (bundleIdentifier: String, version: String?)? {
        guard let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return nil
        }

        let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let version = (shortVersion?.isEmpty == false ? shortVersion : nil) ?? (buildVersion?.isEmpty == false ? buildVersion : nil)

        return (bundleIdentifier, version)
    }

    private func createAvailableDirectories(from supportedApp: SupportedApplication, appVersion: String?) -> [AvailableDirectory] {
        SupportedPathResolver.resolveDirectories(for: supportedApp, appVersion: appVersion).map { resolvedDirectory in
            AvailableDirectory(
                name: resolvedDirectory.name,
                path: resolvedDirectory.path,
                type: resolvedDirectory.type,
                isSelected: resolvedDirectory.exists
            )
        }
    }
}

struct MultipleAppRowView: View {
    let detectedApp: DetectedApplication
    let isSupported: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = AppLoader.shared.getAppIcon(for: detectedApp.bundlePath) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSupported ? Color.accentColor : Color.orange, lineWidth: 2)
                    )
            } else {
                Image(systemName: isSupported ? "app.badge.checkmark" : "app.badge.questionmark")
                    .font(.title2)
                    .foregroundColor(isSupported ? .accentColor : .orange)
            }

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

                    if detectedApp.isAlreadyAdded {
                        Text("Already Added")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }

                    if isSupported && !detectedApp.isAlreadyAdded {
                        Text("(\(detectedApp.availableDirectories.count) paths)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(detectedApp.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let appVersion = detectedApp.appVersion {
                    Text("Version \(appVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(detectedApp.bundlePath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
    let isAlreadyAdded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: {
            if !isAlreadyAdded {
                onToggle()
            }
        }) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: checkboxIcon)
                    .font(.title3)
                    .foregroundColor(checkboxColor)

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
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let version = app.version {
                            Text("v\(version)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.secondarySystemFill))
                                .cornerRadius(4)
                        }
                    }

                    if isAlreadyAdded {
                        Text("Already Added")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }

                    if let bundleID = app.bundleIdentifier {
                        Text(bundleID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(app.bundlePath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var checkboxIcon: String {
        if isAlreadyAdded {
            return "checkmark.circle.fill"
        }
        return isSelected ? "checkmark.square.fill" : "square"
    }

    private var checkboxColor: Color {
        if isAlreadyAdded {
            return .green
        }
        return isSelected ? .accentColor : .secondary
    }

    private var backgroundColor: Color {
        if isAlreadyAdded {
            return Color.green.opacity(0.08)
        }
        return isSelected ? Color.accentColor.opacity(0.1) : Color.clear
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

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // App icon
                        if let icon = AppLoader.shared.getAppIcon(for: detectedApp.bundlePath) {
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

                        VStack(spacing: 4) {
                            Text("Add Custom Path")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("for \(detectedApp.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
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
        .background(Color(.windowBackgroundColor))
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
