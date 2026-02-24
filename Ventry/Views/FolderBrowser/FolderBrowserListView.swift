import SwiftUI

struct FolderBrowserListView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemDoubleClick: (FolderBrowserItem) -> Void
    let onItemClick: (FolderBrowserItem, _ isCommandKey: Bool) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu
    let onDropOnItem: ([URL], FolderBrowserItem) -> Bool
    let onDropInCurrentDirectory: ([URL]) -> Bool
    let onInternalDragBegan: ([URL]) -> Void

    @State private var dropTargetItemID: UUID?
    @Namespace private var dragContainerNamespace

    var body: some View {
        List {
            ForEach(items) { item in
                ListItemView(
                    item: item,
                    isSelected: selectedItems.contains(item),
                    isDropTargeted: dropTargetItemID == item.id
                )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .onTapGesture(count: 2) {
                        onItemDoubleClick(item)
                    }
                    .highPriorityGesture(
                        TapGesture(count: 1).onEnded {
                            let commandPressed = NSEvent.modifierFlags.contains(.command)
                            onItemClick(item, commandPressed)
                        }
                    )
                    .contextMenu {
                        let itemsForMenu = selectedItems.contains(item) ? Array(selectedItems) : [item]
                        contextMenuBuilder(itemsForMenu)
                    }
                    .contentShape(Rectangle())
                    #if compiler(>=5.3) && $NonescapableTypes
                    .draggable(
                        containerItemID: item.url.standardizedFileURL,
                        containerNamespace: dragContainerNamespace
                    )
                    #else
                    .onDrag {
                        let draggedURLs: [URL] = selectedItems.contains(item)
                            ? selectedItems.map { $0.url.standardizedFileURL }
                            : [item.url.standardizedFileURL]
                        onInternalDragBegan(draggedURLs)
                        return NSItemProvider(object: item.url.standardizedFileURL as NSURL)
                    }
                    #endif
                    .dropDestination(for: URL.self) { droppedURLs, _ in
                        guard item.isDirectory else { return false }
                        return onDropOnItem(droppedURLs, item)
                    } isTargeted: { isTargeted in
                        if isTargeted {
                            dropTargetItemID = item.id
                        } else if dropTargetItemID == item.id {
                            dropTargetItemID = nil
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        #if compiler(>=5.3) && $NonescapableTypes
        .dragContainerSelection(
            Array(selectedItems.map { $0.url.standardizedFileURL }),
            containerNamespace: dragContainerNamespace
        )
        .dragContainer(for: FolderBrowserDraggedItem.self, in: dragContainerNamespace) { draggedItemIDs in
            onInternalDragBegan(draggedItemIDs)
            return draggedItemIDs.map { FolderBrowserDraggedItem(url: $0) }
        }
        #endif
        .dropDestination(for: URL.self) { droppedURLs, _ in
            return onDropInCurrentDirectory(droppedURLs)
        }
    }
}

private struct ListItemView: View {
    let item: FolderBrowserItem
    let isSelected: Bool
    let isDropTargeted: Bool

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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
    }

    private var backgroundColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.15)
        }
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        return Color.clear
    }
}
