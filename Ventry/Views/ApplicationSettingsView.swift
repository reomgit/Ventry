import SwiftUI
import UniformTypeIdentifiers

struct ApplicationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddDirectory = false
    @State private var selectedApplication: Application?
    @State private var showingApplicationScanner = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with scan button
                HStack {
                    Text("Applications")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if appState.isScanning {
                    VStack(spacing: 16) {
                        ProgressView(value: appState.scanProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("Scanning applications...")
                            .font(.headline)
                        
                        Text("\(Int(appState.scanProgress * 100))% complete")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                        
                        Text("Scan for Applications")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("This will search your Applications folder for supported applications and their directories.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: scanApplications) {
                        Text("Start Scan")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Application Scanner")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            #endif
        }
    }
    
    private func scanApplications() {
        Task {
            await appState.refreshApplications()
        }
    }
}

#Preview {
    ApplicationSettingsView()
        .environmentObject(AppState())
}