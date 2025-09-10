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
