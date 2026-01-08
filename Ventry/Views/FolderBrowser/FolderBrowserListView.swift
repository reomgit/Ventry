import SwiftUI

struct FolderBrowserListView: View {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemDoubleClick: (FolderBrowserItem) -> Void
    let onItemClick: (FolderBrowserItem, _ isCommandKey: Bool) -> Void

    var body: some View {
        List(selection: Binding(
            get: { selectedItems },
            set: { selectedItems = $0 }
        )) {
            ForEach(items) { item in
                ListItemView(item: item)
                    .tag(item)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .onTapGesture(count: 2) {
                        onItemDoubleClick(item)
                    }
                    .onTapGesture {
                        let commandPressed = NSEvent.modifierFlags.contains(.command)
                        onItemClick(item, commandPressed)
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

private struct ListItemView: View {
    let item: FolderBrowserItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.iconName)
                .font(.system(size: 18))
                .foregroundColor(item.iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24, height: 24)

            // Name
            Text(item.displayName)
                .font(.system(size: 13))
                .lineLimit(1)
                .frame(minWidth: 200, alignment: .leading)

            Spacer()

            // File size
            Text(item.formattedFileSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            // Modification date
            Text(item.formattedModificationDate)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}
