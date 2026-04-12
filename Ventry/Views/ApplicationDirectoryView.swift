import SwiftUI

struct ApplicationDirectoryView: View {
    @EnvironmentObject var appState: AppState
    let applicationId: UUID
    let onOpenDirectory: (AppDirectory, Application) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    private var application: Application? {
        appState.applications.first { $0.id == applicationId }
    }
    
    var body: some View {
        Group {
            if let application {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(application.directories) { directory in
                            Button {
                                onOpenDirectory(directory, application)
                            } label: {
                                DirectoryCardView(directory: directory)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .navigationTitle(application.name)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "app.badge.xmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Application Not Found")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("This application may have been removed from Ventry.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
