import SwiftUI

struct FolderBrowserColumnView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemDoubleClick: (FolderBrowserItem) -> Void
    let onItemClick: (FolderBrowserItem, _ isCommandKey: Bool) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu
    let onDropOnItem: ([URL], FolderBrowserItem) -> Bool
    let onDropInCurrentDirectory: ([URL]) -> Bool
    let onInternalDragBegan: ([URL]) -> Void

    @State private var dropTargetItemID: UUID?
    @State private var pointerDownItemID: UUID?
    @Namespace private var dragContainerNamespace

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
                        isSelected: selectedItems.contains(item),
                        isDropTargeted: dropTargetItemID == item.id
                    )
                    .onTapGesture(count: 2) {
                        onItemDoubleClick(item)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard pointerDownItemID != item.id else { return }
                                pointerDownItemID = item.id
                                let commandPressed = NSEvent.modifierFlags.contains(.command)
                                onItemClick(item, commandPressed)
                            }
                            .onEnded { _ in
                                if pointerDownItemID == item.id {
                                    pointerDownItemID = nil
                                }
                            }
                    )
                    .contextMenu {
                        let itemsForMenu = selectedItems.contains(item) ? Array(selectedItems) : [item]
                        contextMenuBuilder(itemsForMenu)
                    }
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
            .padding()
        }
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

private struct ColumnItemView: View {
    let item: FolderBrowserItem
    let isSelected: Bool
    let isDropTargeted: Bool

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
                .fill(
                    isDropTargeted
                    ? Color.accentColor.opacity(0.2)
                    : (isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isDropTargeted ? Color.accentColor : (isSelected ? Color.accentColor : Color.clear),
                    lineWidth: 1
                )
        )
    }
}
