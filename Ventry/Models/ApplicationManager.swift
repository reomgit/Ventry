import Foundation
import Combine

// This manager encapsulates scanning and managing applications/directories.
// It provides the properties and methods AppState relies on.
final class ApplicationManager: ObservableObject {
    // Initialization state
    @Published var isInitialized: Bool = false
    
    // Multiple installations handling
    // When true, AppState will present a sheet using pendingMultipleInstallations.first
    @Published var showingMultipleInstallationsAlert: Bool = false
    
    // Queue of (baseName, installations) awaiting user selection
    // AppState expects DetectedApplication from MultipleInstallationsView, which uses ApplicationScanner.DetectedApplication.
    // To bridge without introducing a separate ApplicationScanner type across the app,
    // we’ll define a nested struct mirroring that shape and provide conversion helpers.
    typealias DetectedApplication = ApplicationScannerDetectedApplication
    @Published private(set) var pendingMultipleInstallations: [(String, [DetectedApplication])] = []
    
    // Scanning status for progress UI
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanProgress: Double = 0.0
    
    // Storage for applications; AppState owns its own list, but we may keep internal state if needed.
    private var storedApplications: [Application] = []

    // Supported applications loaded from JSON
    private var _supportedApplications: [String: SupportedApplication] = [:]

    // Public access to supported applications for views
    var supportedApplications: [String: SupportedApplication] {
        return _supportedApplications
    }

    // Get supported applications dictionary for AppLoader
    func getSupportedApplications() -> [String: SupportedApplication] {
        return _supportedApplications
    }
    
    init() {
        loadSupportedApplications()

        // Simulate async initialization to trigger AppState refresh
        Task { @MainActor in
            self.isInitialized = true
        }
    }
    
    // MARK: - Public API expected by AppState
    
    func scanApplications() async -> [Application] {
        // Simulate a scan with progress updates and return whatever we have stored.
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.startScanningSimulation {
                    continuation.resume(returning: self.storedApplications)
                }
            }
        }
    }
    
    func addCustomDirectory(for bundleIdentifier: String, directory: AppDirectory) {
        if let index = storedApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            var app = storedApplications[index]
            app.addDirectory(directory)
            storedApplications[index] = app
        } else {
            // If the app isn't stored yet, create a placeholder Application so the directory persists.
            let placeholder = Application(name: bundleIdentifier, bundleIdentifier: bundleIdentifier, bundlePath: nil, directories: [directory])
            storedApplications.append(placeholder)
        }
    }
    
    func removeCustomDirectory(for bundleIdentifier: String, directoryId: UUID) {
        if let index = storedApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            var app = storedApplications[index]
            app.removeDirectory(withId: directoryId)
            storedApplications[index] = app
        }
    }
    
    // Called when user selects one of multiple installations in the sheet
    func selectApplicationVersion(baseName: String, selectedApp: DetectedApplication) async -> Application? {
        // Convert the selected detected app into an Application. In a real implementation,
        // you would also resolve configured directories. Here we leave it empty by default.
        let application = Application(
            name: selectedApp.name,
            bundleIdentifier: selectedApp.bundleIdentifier,
            bundlePath: selectedApp.appURL.path,
            directories: []
        )
        
        // Remove the handled baseName from the pending queue
        await MainActor.run {
            if let idx = pendingMultipleInstallations.firstIndex(where: { $0.0 == baseName }) {
                pendingMultipleInstallations.remove(at: idx)
            }
            if pendingMultipleInstallations.isEmpty {
                showingMultipleInstallationsAlert = false
            }
            // Store/update internal list
            if let existing = storedApplications.firstIndex(where: { $0.bundleIdentifier == application.bundleIdentifier }) {
                storedApplications[existing] = application
            } else {
                storedApplications.append(application)
            }
        }
        
        return application
    }
    
    func dismissMultipleInstallations(for baseName: String) {
        if let idx = pendingMultipleInstallations.firstIndex(where: { $0.0 == baseName }) {
            pendingMultipleInstallations.remove(at: idx)
        }
        if pendingMultipleInstallations.isEmpty {
            showingMultipleInstallationsAlert = false
        }
    }
    
    func getAvailableApplications() async -> [String] {
        // Return bundle identifiers of stored applications
        return storedApplications.map { $0.bundleIdentifier }
    }
    
    // MARK: - Simulated triggers
    
    // You can call this method to enqueue a multiple-installations choice prompt.
    // AppState is already observing showingMultipleInstallationsAlert and will present the sheet automatically.
    func enqueueMultipleInstallationsPrompt(baseName: String, installations: [DetectedApplication]) {
        pendingMultipleInstallations.append((baseName, installations))
        showingMultipleInstallationsAlert = true
    }
    
    // MARK: - Private helpers
    
    private func startScanningSimulation(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanProgress = 0.0
        }

        let steps = 10
        let stepDelay: TimeInterval = 0.05
        for i in 1...steps {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * stepDelay) {
                DispatchQueue.main.async {
                    self.scanProgress = Double(i) / Double(steps)
                    if i == steps {
                        self.isScanning = false
                        completion()
                    }
                }
            }
        }
    }

    // MARK: - JSON Loading

    private func loadSupportedApplications() {
        guard let url = Bundle.main.url(forResource: "SupportedApplications", withExtension: "json") else {
            print("Failed to find SupportedApplications.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let jsonResponse = try JSONDecoder().decode(SupportedApplicationsResponse.self, from: data)
            self._supportedApplications = jsonResponse.supportedApplications
        } catch {
            print("Failed to load supported applications: \(error)")
        }
    }

    func getSupportedApplication(for bundleIdentifier: String) -> SupportedApplication? {
        return _supportedApplications[bundleIdentifier]
    }

    func isApplicationSupported(_ bundleIdentifier: String) -> Bool {
        return _supportedApplications[bundleIdentifier] != nil
    }
}

// A lightweight stand-in for MultipleInstallationsView's ApplicationScanner.DetectedApplication,
// and AppState's expected DetectedApplication in its tuple (String, [DetectedApplication]).
// This keeps the app compiling without introducing a larger scanning subsystem here.
// If you later add a real ApplicationScanner type, you can replace references accordingly.
struct ApplicationScannerDetectedApplication: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let version: String?
    let bundleIdentifier: String
    let appURL: URL
    let installationPath: String
}

// MARK: - JSON Data Structures

struct SupportedApplicationsResponse: Codable {
    let supportedApplications: [String: SupportedApplication]
}

public struct SupportedApplication: Codable {
    public let displayName: String
    public let appPaths: [String]
    public let paths: [SupportedPath]
}

public struct SupportedPath: Codable {
    public let name: String
    public let path: String
    public let type: String
    public let icon: String
}
