import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var selectedCollection: Collection? = nil
    
    init() {
        loadMockData()
    }
    
    private func loadMockData() {
        let designAssets = [
            Asset(name: "Logo Design", type: .image),
            Asset(name: "Brand Guidelines", type: .document),
            Asset(name: "Color Palette", type: .image),
            Asset(name: "Typography Sample", type: .document)
        ]
        
        let projectFiles = [
            Asset(name: "Project Proposal", type: .document),
            Asset(name: "Meeting Recording", type: .video),
            Asset(name: "Client Feedback", type: .audio),
            Asset(name: "Final Presentation", type: .document)
        ]
        
        let mediaLibrary = [
            Asset(name: "Background Music", type: .audio),
            Asset(name: "Product Photos", type: .image),
            Asset(name: "Tutorial Video", type: .video),
            Asset(name: "Stock Images Archive", type: .archive),
            Asset(name: "Sound Effects", type: .audio)
        ]
        
        let miscAssets = [
            Asset(name: "Contract Template", type: .document),
            Asset(name: "Invoice Generator", type: .other),
            Asset(name: "Team Photo", type: .image)
        ]
        
        collections = [
            Collection(name: "Design Assets", assets: designAssets),
            Collection(name: "Project Files", assets: projectFiles),
            Collection(name: "Media Library", assets: mediaLibrary),
            Collection(name: "Miscellaneous", assets: miscAssets)
        ]
        
        selectedCollection = collections.first
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