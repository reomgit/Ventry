import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var starredItems: [StarredItem] = []
    @Published var regularFolders: [RegularFolder] = RegularFolder.allCases
    @Published var applications: [Application] = []
    @Published var userTags: [UserTag] = []
    @Published var isLoadingApplications = false
    @Published var showingMultipleInstallationsSheet = false
    @Published var pendingInstallationSelection: (String, [ApplicationManager.DetectedApplication])? = nil

    // New: Store loaded apps before scanning
    @Published var loadedApps: [AppLoader.LoadedApp] = []
    @Published var isLoadingApps = false
    @Published var hasAccess = false

    private let applicationManager = ApplicationManager()
    private var cancellables = Set<AnyCancellable>()

    // Provide access to applicationManager for views that need it
    var applicationManagerAccess: ApplicationManager {
        return applicationManager
    }
    
    init() {
        setupBindings()
        
        // Check initial access state
        hasAccess = PermissionManager.shared.hasDirectoryAccess
        
        // Only load apps if we have access
        if hasAccess {
            Task {
                await loadApplicationsFromSystem()
            }
        }
    }

    /// Loads all .app files from /Applications folder (runs on app launch)
    func loadApplicationsFromSystem() async {
        await MainActor.run {
            isLoadingApps = true
        }

        let supportedApps = applicationManager.getSupportedApplications()
        let apps = await AppLoader.shared.loadAllApplications(supportedApps: supportedApps)

        await MainActor.run {
            self.loadedApps = apps
            self.isLoadingApps = false
        }
    }
    
    private func setupBindings() {
        PermissionManager.shared.$hasDirectoryAccess
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAccess in
                self?.hasAccess = hasAccess
                if hasAccess {
                    Task {
                        await self?.loadApplicationsFromSystem()
                    }
                }
            }
            .store(in: &cancellables)
            
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
    
    func selectApplicationInstallation(_ selectedApp: ApplicationManager.DetectedApplication) {
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
    func addCollection(_ collection: Collection) {
        collections.append(collection)
    }
    
    func removeCollection(withId id: UUID) {
        collections.removeAll { $0.id == id }
    }
}
