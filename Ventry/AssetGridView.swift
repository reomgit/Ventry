import SwiftUI

struct AssetGridView: View {
    let collection: Collection
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(collection.assets) { asset in
                    AssetCardView(asset: asset)
                }
            }
            .padding()
        }
        .navigationTitle(collection.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

struct AssetCardView: View {
    let asset: Asset
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .frame(height: 120)
                .overlay(
                    Image(systemName: asset.type.systemImage)
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(asset.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
}