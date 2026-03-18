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
    private let starredItemsStore = StarredItemsStore.shared
    private var cancellables = Set<AnyCancellable>()

    // Provide access to applicationManager for views that need it
    var applicationManagerAccess: ApplicationManager {
        return applicationManager
    }
    
    init() {
        setupBindings()
        _ = AppStorageManager.shared.prepareDirectories()

        hasAccess = true

        Task {
            await loadApplicationsFromSystem()
            await loadSavedCollections()
            await loadSavedStarredItems()
            await validateAllPaths()
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
            .sink { [weak self] _ in
                self?.hasAccess = true
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

        NotificationCenter.default.publisher(for: .starredItemsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }

                if let items = notification.object as? [StarredItem] {
                    self.starredItems = items
                } else {
                    self.starredItems = self.starredItemsStore.currentItems()
                }

                Task { @MainActor in
                    await self.validateAllPaths()
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
        applicationManager.addCustomDirectory(
            for: application.id,
            bundleIdentifier: application.bundleIdentifier,
            directory: directory
        )
        
        // Update the application in our list
        if let index = applications.firstIndex(where: { $0.id == application.id }) {
            var updatedApplication = applications[index]
            updatedApplication.addDirectory(directory)
            applications[index] = updatedApplication
        }

        Task { @MainActor in
            await validateAllPaths()
        }
    }
    
    func removeCustomDirectory(for application: Application, directoryId: UUID) {
        applicationManager.removeCustomDirectory(
            for: application.id,
            bundleIdentifier: application.bundleIdentifier,
            directoryId: directoryId
        )
        
        // Update the application in our list
        if let index = applications.firstIndex(where: { $0.id == application.id }) {
            var updatedApplication = applications[index]
            updatedApplication.removeDirectory(withId: directoryId)
            applications[index] = updatedApplication
        }

        Task { @MainActor in
            await validateAllPaths()
        }
    }

    func updateCustomDirectory(for application: Application, directory: AppDirectory) {
        applicationManager.updateCustomDirectory(
            for: application.id,
            bundleIdentifier: application.bundleIdentifier,
            directory: directory
        )

        // Update the application in our list
        if let index = applications.firstIndex(where: { $0.id == application.id }),
           let directoryIndex = applications[index].directories.firstIndex(where: { $0.id == directory.id }) {
            var updatedApplication = applications[index]
            updatedApplication.directories[directoryIndex] = directory
            applications[index] = updatedApplication
        }

        Task { @MainActor in
            await validateAllPaths()
        }
    }

    func removeApplication(_ application: Application) {
        applicationManager.removeApplication(
            applicationId: application.id,
            installKey: application.installKey,
            bundleIdentifier: application.bundleIdentifier
        )
        applications.removeAll { $0.id == application.id }

        Task { @MainActor in
            await validateAllPaths()
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
                    if let existingIndex = applications.firstIndex(where: { $0.installKey == newApplication.installKey }) {
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
    func loadSavedCollections() async {
        do {
            let loaded = try CollectionManager.shared.loadAllCollections()
            await MainActor.run {
                self.collections = loaded
                print("Loaded \(loaded.count) collections from disk")
            }
        } catch {
            print("Failed to load collections: \(error)")
        }
    }

    func loadSavedStarredItems() async {
        do {
            let loaded = try starredItemsStore.reloadFromDisk()
            await MainActor.run {
                self.starredItems = loaded
                print("Loaded \(loaded.count) starred items from disk")
            }
        } catch {
            await MainActor.run {
                self.starredItems = starredItemsStore.currentItems()
            }
            print("Failed to load starred items: \(error)")
        }
    }

    func isStarred(_ item: FolderBrowserItem) -> Bool {
        isStarred(path: item.url.standardizedFileURL.path)
    }

    func isStarred(path: String) -> Bool {
        starredItems.contains { $0.path == path }
    }

    func addStarredItems(_ items: [FolderBrowserItem]) throws {
        let newItems = items.map { item in
            StarredItem(
                name: item.displayName,
                type: item.isDirectory ? .folder : .file,
                path: item.url.standardizedFileURL.path
            )
        }

        try starredItemsStore.add(items: newItems)
    }

    func removeStarredItems(_ items: [FolderBrowserItem]) throws {
        for item in items {
            try starredItemsStore.remove(path: item.url.standardizedFileURL.path)
        }
    }

    func removeStarredItem(_ item: StarredItem) throws {
        try starredItemsStore.remove(item)
    }

    func moveStarredItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try starredItemsStore.moveItems(fromOffsets: source, toOffset: destination)
        } catch {
            print("Failed to reorder starred items: \(error)")
        }
    }

    func addCollection(_ collection: Collection) {
        collections.append(collection)

        // Persist to disk
        Task {
            do {
                try CollectionManager.shared.saveCollection(collection)
            } catch {
                print("Failed to save collection: \(error)")
            }
        }
    }

    func removeCollection(withId id: UUID) {
        collections.removeAll { $0.id == id }

        // Remove from disk
        Task {
            do {
                try CollectionManager.shared.deleteCollection(id)
            } catch {
                print("Failed to delete collection: \(error)")
            }
        }
    }

    func refreshCollection(_ collection: Collection) async {
        do {
            let updated = try await CollectionManager.shared.refreshCollection(collection)

            await MainActor.run {
                if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                    collections[index] = updated
                }
            }
        } catch {
            print("Failed to refresh collection: \(error)")
        }
    }

    // MARK: - Path Validation

    /// Validates user-saved external paths that should remain accessible between launches
    func validateAllPaths() async {
        var pathsToValidate = Set<String>()

        // Add all application directory paths
        for application in applications {
            for directory in application.directories {
                pathsToValidate.insert(directory.path)
            }
        }

        // Add starred item paths
        for starredItem in starredItems {
            if let path = starredItem.path {
                pathsToValidate.insert(path)
            }
        }

        // Add collection paths
        for collection in collections {
            pathsToValidate.insert(collection.path)
        }

        // Validate all paths
        await MainActor.run {
            PermissionManager.shared.validateRequiredPaths(Array(pathsToValidate))
        }
    }

    /// Re-validates paths after permission changes
    func revalidatePaths() async {
        await loadSavedStarredItems()
        await validateAllPaths()
    }
}
