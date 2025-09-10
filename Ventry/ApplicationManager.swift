import Foundation
import SwiftUI
import Combine

class ApplicationManager: ObservableObject {
    @Published var isInitialized = false
    @Published var customDirectories: [String: [AppDirectory]] = [:]
    
    private let scanner = ApplicationScanner.shared
    private let userDefaults = UserDefaults.standard
    private let customDirectoriesKey = "CustomDirectories"
    
    init() {
        loadCustomDirectories()
    }
    
    func initializeApplications() async {
        let scannedApplications = await scanner.scanForApplications()
        
        await MainActor.run {
            // This will be set on AppState through the app initialization
            self.isInitialized = true
        }
    }
    
    func scanApplications() async -> [Application] {
        return await scanner.scanForApplications()
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