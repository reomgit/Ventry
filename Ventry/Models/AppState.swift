import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var selectedCollection: Collection? = nil
    @Published var starredItems: [StarredItem] = []
    @Published var regularFolders: [RegularFolder] = RegularFolder.allCases
    @Published var applications: [Application] = []
    @Published var userTags: [UserTag] = []
    @Published var isLoadingApplications = false
    @Published var showingMultipleInstallationsSheet = false
    @Published var pendingInstallationSelection: (String, [ApplicationScanner.DetectedApplication])? = nil
    
    private let applicationManager = ApplicationManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        Task {
            await initializeApplications()
        }
    }
    
    private func setupBindings() {
        applicationManager.$isInitialized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshApplications()
                }
            }
            .store(in: &cancellables)
        
        applicationManager.$showingMultipleInstallationsAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                if showing, let firstPending = self?.applicationManager.pendingMultipleInstallations.first {
                    self?.pendingInstallationSelection = firstPending
                    self?.showingMultipleInstallationsSheet = true
                }
            }
            .store(in: &cancellables)
    }
    
    func initializeApplications() async {
        await MainActor.run {
            isLoadingApplications = true
        }
        
        let scannedApps = await applicationManager.scanApplications()
        
        await MainActor.run {
            self.applications = scannedApps
            self.isLoadingApplications = false
        }
    }
    
    func refreshApplications() async {
        let scannedApps = await applicationManager.scanApplications()
        
        await MainActor.run {
            self.applications = scannedApps
        }
    }
    
    func addCustomDirectory(for application: Application, directory: AppDirectory) {
        applicationManager.addCustomDirectory(for: application.bundleIdentifier, directory: directory)
        
        // Update the application in our list
        if let index = applications.firstIndex(where: { $0.id == application.id }) {
            applications[index].addDirectory(directory)
        }
    }
    
    func removeCustomDirectory(for application: Application, directoryId: UUID) {
        applicationManager.removeCustomDirectory(for: application.bundleIdentifier, directoryId: directoryId)
        
        // Update the application in our list
        if let index = applications.firstIndex(where: { $0.id == application.id }) {
            applications[index].removeDirectory(withId: directoryId)
        }
    }
    
    var isScanning: Bool {
        applicationManager.isScanning
    }
    
    var scanProgress: Double {
        applicationManager.scanProgress
    }
    
    func selectApplicationInstallation(_ selectedApp: ApplicationScanner.DetectedApplication) {
        guard let (baseName, _) = pendingInstallationSelection else { return }
        
        Task {
            if let newApplication = await applicationManager.selectApplicationVersion(baseName: baseName, selectedApp: selectedApp) {
                await MainActor.run {
                    // Add the selected application to our list
                    if let existingIndex = applications.firstIndex(where: { $0.bundleIdentifier == newApplication.bundleIdentifier }) {
                        applications[existingIndex] = newApplication
                    } else {
                        applications.append(newApplication)
                    }
                    
                    // Check if there are more pending selections
                    if let nextPending = applicationManager.pendingMultipleInstallations.first {
                        pendingInstallationSelection = nextPending
                    } else {
                        showingMultipleInstallationsSheet = false
                        pendingInstallationSelection = nil
                    }
                }
            }
        }
    }
    
    func dismissInstallationSelection() {
        guard let (baseName, _) = pendingInstallationSelection else { return }
        
        applicationManager.dismissMultipleInstallations(for: baseName)
        
        // Check if there are more pending selections
        if let nextPending = applicationManager.pendingMultipleInstallations.first {
            pendingInstallationSelection = nextPending
        } else {
            showingMultipleInstallationsSheet = false
            pendingInstallationSelection = nil
        }
    }
    
    func getAvailableApplications() async -> [String] {
        return await applicationManager.getAvailableApplications()
    }
    
    func selectCollection(_ collection: Collection) {
        selectedCollection = collection
    }
    
    func addCollection(_ collection: Collection) {
        collections.append(collection)
    }
    
    func removeCollection(withId id: UUID) {
        collections.removeAll { $0.id == id }
        if selectedCollection?.id == id {
            selectedCollection = collections.first
        }
    }
}
