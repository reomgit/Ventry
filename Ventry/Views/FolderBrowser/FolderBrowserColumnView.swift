import SwiftUI

struct FolderBrowserColumnView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemDoubleClick: (FolderBrowserItem) -> Void
    let onItemClick: (FolderBrowserItem, _ isCommandKey: Bool) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu

    private let columns = [
        GridItem(.flexible(minimum: 150), spacing: 20),
        GridItem(.flexible(minimum: 150), spacing: 20),
        GridItem(.flexible(minimum: 150), spacing: 20),
        GridItem(.flexible(minimum: 150), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    ColumnItemView(
                        item: item,
                        isSelected: selectedItems.contains(item)
                    )
                    .onTapGesture(count: 2) {
                        onItemDoubleClick(item)
                    }
                    .onTapGesture {
                        let commandPressed = NSEvent.modifierFlags.contains(.command)
                        onItemClick(item, commandPressed)
                    }
                    .contextMenu {
                        let itemsForMenu = selectedItems.contains(item) ? Array(selectedItems) : [item]
                        contextMenuBuilder(itemsForMenu)
                    }
                }
            }
            .padding()
        }
    }
}

private struct ColumnItemView: View {
    let item: FolderBrowserItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.iconName)
                .font(.system(size: 16))
                .foregroundColor(item.iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text(item.formattedFileSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if !item.isDirectory {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)

                        Text(item.formattedModificationDate)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}
