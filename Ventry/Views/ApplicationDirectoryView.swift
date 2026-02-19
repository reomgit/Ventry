import SwiftUI

struct ApplicationDirectoryView: View {
    let application: Application
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(application.directories) { directory in
                    NavigationLink(
                        destination: FolderBrowserView(
                            title: "\(application.name) • \(directory.name)",
                            path: directory.path
                        )
                    ) {
                        DirectoryCardView(directory: directory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(application.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

struct DirectoryCardView: View {
    let directory: AppDirectory
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .frame(height: 120)
                .overlay(
                    Image(systemName: directory.type.systemImage)
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(directory.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(directory.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(directory.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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
        .contentShape(Rectangle())
    }
}
