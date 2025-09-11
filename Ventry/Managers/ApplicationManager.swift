import Foundation
import SwiftUI
import Combine

class ApplicationManager: ObservableObject {
    @Published var isInitialized = false
    @Published var customDirectories: [String: [AppDirectory]] = [:]
    @Published var showingMultipleInstallationsAlert = false
    @Published var pendingMultipleInstallations: [String: [ApplicationScanner.DetectedApplication]] = [:]
    
    private let scanner = ApplicationScanner.shared
    private let permissionManager = PermissionManager.shared
    private let userDefaults = UserDefaults.standard
    private let customDirectoriesKey = "CustomDirectories"
    
    init() {
        loadCustomDirectories()
    }
    
    func initializeApplications() async {
        _ = await scanner.scanForApplications()
        
        await MainActor.run {
            // This will be set on AppState through the app initialization
            self.isInitialized = true
        }
    }
    
    func scanApplications() async -> [Application] {
        let applications = await scanner.scanForApplications()
        
        // Check for multiple installations that need user selection
        await MainActor.run {
            pendingMultipleInstallations = scanner.multipleInstallationsFound
            showingMultipleInstallationsAlert = !pendingMultipleInstallations.isEmpty
        }
        
        return applications
    }
    
    func selectApplicationVersion(baseName: String, selectedApp: ApplicationScanner.DetectedApplication) async -> Application? {
        let application = await scanner.selectApplicationVersion(baseName: baseName, selectedApp: selectedApp)
        
        await MainActor.run {
            // Remove from pending installations
            pendingMultipleInstallations.removeValue(forKey: baseName)
            
            // Hide alert if no more pending installations
            if pendingMultipleInstallations.isEmpty {
                showingMultipleInstallationsAlert = false
            }
        }
        
        return application
    }
    
    func dismissMultipleInstallations(for baseName: String) {
        pendingMultipleInstallations.removeValue(forKey: baseName)
        
        if pendingMultipleInstallations.isEmpty {
            showingMultipleInstallationsAlert = false
        }
    }
    
    func getAvailableApplications() async -> [String] {
        return await scanner.getAvailableApplications()
    }
    
    func addCustomDirectory(for bundleIdentifier: String, directory: AppDirectory) {
        if customDirectories[bundleIdentifier] == nil {
            customDirectories[bundleIdentifier] = []
        }
        
        // Check if directory already exists
        if !customDirectories[bundleIdentifier]!.contains(where: { $0.path == directory.path }) {
            customDirectories[bundleIdentifier]!.append(directory)
            saveCustomDirectories()
        }
    }
    
    func removeCustomDirectory(for bundleIdentifier: String, directoryId: UUID) {
        customDirectories[bundleIdentifier]?.removeAll { $0.id == directoryId }
        saveCustomDirectories()
    }
    
    func getCustomDirectories(for bundleIdentifier: String) -> [AppDirectory] {
        return customDirectories[bundleIdentifier] ?? []
    }
    
    func createApplicationWithCustomDirectories(
        name: String,
        bundleIdentifier: String,
        directories: [AppDirectory]
    ) -> Application {
        return scanner.addCustomApplication(
            name: name,
            bundleIdentifier: bundleIdentifier,
            customDirectories: directories
        )
    }
    
    private func loadCustomDirectories() {
        if let data = userDefaults.data(forKey: customDirectoriesKey),
           let decoded = try? JSONDecoder().decode([String: [AppDirectory]].self, from: data) {
            customDirectories = decoded
        }
    }
    
    private func saveCustomDirectories() {
        if let encoded = try? JSONEncoder().encode(customDirectories) {
            userDefaults.set(encoded, forKey: customDirectoriesKey)
        }
    }
    
    var isScanning: Bool {
        scanner.isScanning
    }
    
    var scanProgress: Double {
        scanner.scanProgress
    }
}