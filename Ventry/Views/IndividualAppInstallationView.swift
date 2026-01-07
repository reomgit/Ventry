import SwiftUI
import UniformTypeIdentifiers

struct IndividualAppInstallationView: View {
    let detectedApp: DetectedApplication
    let isSupported: Bool
    let currentAppIndex: Int
    let totalApps: Int
    let onInstall: (DetectedApplication) -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var availableDirectories: [AvailableDirectory] = []
    @State private var showingAddPathsNow = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            HStack {
                Button("Cancel All") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                VStack(spacing: 4) {
                    Text("Installing Applications")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("\(currentAppIndex + 1) of \(totalApps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Skip") {
                        onSkip()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if isSupported {
                        Button("Install") {
                            installSelectedDirectories()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(availableDirectories.filter { $0.isSelected }.isEmpty)
                    } else {
                        Button("Add Paths") {
                            showingAddPathsNow = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding()

            Divider()

            if isSupported {
                // Supported app - show directories selection
                SupportedAppInstallationView(
                    detectedApp: detectedApp,
                    availableDirectories: $availableDirectories
                )
            } else {
                // Unsupported app - show add paths options
                UnsupportedAppInstallationView(
                    detectedApp: detectedApp,
                    onAddPathsNow: {
                        showingAddPathsNow = true
                    },
                    onAddPathsLater: {
                        installWithoutDirectories()
                    }
                )
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            if isSupported {
                // Initialize available directories for supported apps
                availableDirectories = detectedApp.availableDirectories
            }
        }
        .sheet(isPresented: $showingAddPathsNow) {
            CustomPathsAdditionView(
                detectedApp: detectedApp,
                onComplete: { customDirectories in
                    var updatedApp = detectedApp
                    updatedApp.availableDirectories = customDirectories
                    onInstall(updatedApp)
                }
            )
        }
    }

    private func installSelectedDirectories() {
        var updatedApp = detectedApp
        updatedApp.availableDirectories = availableDirectories
        onInstall(updatedApp)
    }

    private func installWithoutDirectories() {
        var updatedApp = detectedApp
        updatedApp.availableDirectories = []
        onInstall(updatedApp)
    }
}

struct SupportedAppInstallationView: View {
    let detectedApp: DetectedApplication
    @Binding var availableDirectories: [AvailableDirectory]

    var body: some View {
        VStack(spacing: 20) {
            // App info
            VStack(spacing: 12) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                VStack(spacing: 4) {
                    Text(detectedApp.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Supported Application")
                        .font(.headline)
                        .foregroundColor(.accentColor)

                    Text(detectedApp.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Select the directories you want to track for this application:")
                .font(.headline)
                .multilineTextAlignment(.center)

            // Directory selection list
            List {
                ForEach($availableDirectories) { $directory in
                    AvailableDirectoryRowView(directory: $directory)
                }
            }
            .listStyle(PlainListStyle())
        }
        .padding()
    }
}

struct UnsupportedAppInstallationView: View {
    let detectedApp: DetectedApplication
    let onAddPathsNow: () -> Void
    let onAddPathsLater: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // App info
            VStack(spacing: 12) {
                Image(systemName: "app.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                VStack(spacing: 4) {
                    Text(detectedApp.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Unsupported Application")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text(detectedApp.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("This application is not in our supported applications list. You can add custom paths for this application.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Add paths options
            VStack(spacing: 16) {
                Text("Would you like to add custom paths now or later?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: 20) {
                    Button("Add Paths Now") {
                        onAddPathsNow()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Add Paths Later") {
                        onAddPathsLater()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
    }
}

struct CustomPathsAdditionView: View {
    let detectedApp: DetectedApplication
    let onComplete: ([AvailableDirectory]) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var customPaths: [CustomPath] = []
    @State private var showingFileImporter = false
    @State private var currentPathBeingEdited: Int?

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
                    Text("Add Custom Paths")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("for \(detectedApp.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    completeCustomPaths()
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(customPaths.filter { !$0.name.isEmpty && !$0.path.isEmpty }.isEmpty)
            }
            .padding()

            Divider()

            // Custom paths list
            if customPaths.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("No custom paths added")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Add custom directory paths that you want to track for this application.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                List {
                    ForEach(customPaths.indices, id: \.self) { index in
                        CustomPathRowView(
                            customPath: $customPaths[index],
                            onRemove: {
                                customPaths.remove(at: index)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }

            // Add path button
            HStack {
                Button("Add Path") {
                    customPaths.append(CustomPath(name: "", path: "", type: .other))
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func completeCustomPaths() {
        let availableDirectories = customPaths
            .filter { !$0.name.isEmpty && !$0.path.isEmpty }
            .map { customPath in
                AvailableDirectory(
                    name: customPath.name,
                    path: customPath.path,
                    type: customPath.type,
                    isSelected: true
                )
            }

        onComplete(availableDirectories)
        presentationMode.wrappedValue.dismiss()
    }
}

struct CustomPath {
    var name: String
    var path: String
    var type: DirectoryType
}

struct CustomPathRowView: View {
    @Binding var customPath: CustomPath
    let onRemove: () -> Void
    @State private var showingFileImporter = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Path Name", text: $customPath.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Picker("Type", selection: $customPath.type) {
                    ForEach(DirectoryType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.systemImage)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .frame(width: 120)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack {
                TextField("Directory Path", text: $customPath.path)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Browse") {
                    showingFileImporter = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    customPath.path = url.path
                    if customPath.name.isEmpty {
                        customPath.name = url.lastPathComponent
                    }
                }
            case .failure(let error):
                print("File selection error: \(error)")
            }
        }
    }
}

#Preview {
    IndividualAppInstallationView(
        detectedApp: DetectedApplication(
            name: "Test App",
            bundleIdentifier: "com.test.app",
            availableDirectories: []
        ),
        isSupported: false,
        currentAppIndex: 0,
        totalApps: 3,
        onInstall: { _ in },
        onSkip: { },
        onCancel: { }
    )
}