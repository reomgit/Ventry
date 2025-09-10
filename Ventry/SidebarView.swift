import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(appState.collections, selection: .constant(appState.selectedCollection?.id)) { collection in
            CollectionRowView(collection: collection)
                .tag(collection.id)
                .onTapGesture {
                    appState.selectCollection(collection)
                }
        }
        .navigationTitle("Collections")
        .listStyle(SidebarListStyle())
    }
}

struct CollectionRowView: View {
    let collection: Collection
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text("\(collection.assetCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}