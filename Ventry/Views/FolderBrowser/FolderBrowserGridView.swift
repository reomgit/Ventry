import SwiftUI

struct FolderBrowserGridView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemDoubleClick: (FolderBrowserItem) -> Void
    let onItemClick: (FolderBrowserItem, _ isCommandKey: Bool) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu
    let onDropOnItem: ([URL], FolderBrowserItem) -> Bool
    let onDropInCurrentDirectory: ([URL]) -> Bool
    let onInternalDragBegan: ([URL]) -> Void

    @State private var hoveredItem: FolderBrowserItem?
    @State private var dropTargetItemID: UUID?
    @State private var pointerDownItemID: UUID?
    @Namespace private var dragContainerNamespace

    private let gridColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(items) { item in
                    GridItemView(
                        item: item,
                        isSelected: selectedItems.contains(item),
                        isHovered: hoveredItem == item,
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
                    .onHover { hovering in
                        hoveredItem = hovering ? item : nil
                    }
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

private struct GridItemView: View {
    let item: FolderBrowserItem
    let isSelected: Bool
    let isHovered: Bool
    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isDropTargeted
                        ? Color.accentColor.opacity(0.2)
                        : (isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: item.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(item.iconColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDropTargeted ? Color.accentColor : (isSelected ? Color.accentColor : Color.clear),
                        lineWidth: 2
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            )

            // Name
            Text(item.displayName)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(width: 100)
                .padding(.horizontal, 4)
        }
        .frame(width: 100, height: 120)
    }
}
