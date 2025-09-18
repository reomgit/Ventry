import Foundation
import SwiftUI

// MARK: - Installation Flow Models
// These models are specifically for the application installation flow

struct DetectedApplication: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    var availableDirectories: [AvailableDirectory]
}

struct AvailableDirectory: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: DirectoryType
    var isSelected: Bool
}

// MARK: - Supporting Views

struct AvailableDirectoryRowView: View {
    @Binding var directory: AvailableDirectory
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                directory.isSelected.toggle()
            }) {
                Image(systemName: directory.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(directory.isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Image(systemName: directory.type.systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(directory.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(directory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(directory.isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}
