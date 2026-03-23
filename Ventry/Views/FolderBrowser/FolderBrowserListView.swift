import SwiftUI

struct FolderBrowserListView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    let starredPaths: Set<String>
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemMouseDown: (FolderBrowserItem, NSEvent) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu
    let onDropOnItem: ([URL], FolderBrowserItem) -> Bool
    let onDropInCurrentDirectory: ([URL]) -> Bool
    let onInternalDragBegan: ([URL]) -> Void
    let onDragSessionUpdated: (DragSession) -> Void

    @State private var dropTargetItemID: UUID?
    @Namespace private var dragContainerNamespace

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let showSize = width >= 560
            let showDate = width >= 760

            List {
                ForEach(items) { item in
                    ListItemView(
                        item: item,
                        isStarred: starredPaths.contains(item.url.standardizedFileURL.path),
                        isSelected: selectedItems.contains(item),
                        isDropTargeted: dropTargetItemID == item.id,
                        showSize: showSize,
                        showDate: showDate
                    )
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(rowBackgroundView(for: item))
                        .overlay {
                            MouseEventCaptureView { event in
                                onItemMouseDown(item, event)
                            }
                        }
                        .contextMenu {
                            let itemsForMenu = selectedItems.contains(item) ? Array(selectedItems) : [item]
                            contextMenuBuilder(itemsForMenu)
                        }
                        .contentShape(Rectangle())
                        .draggable(
                            containerItemID: item.url.standardizedFileURL,
                            containerNamespace: dragContainerNamespace
                        )
                        .folderBrowserMoveByDefaultDragSource()
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
                        .folderBrowserMoveByDefaultDropTarget()
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .dragContainerSelection(
                Array(selectedItems.map { $0.url.standardizedFileURL }),
                containerNamespace: dragContainerNamespace
            )
            .dragContainer(for: FolderBrowserDraggedItem.self, in: dragContainerNamespace) { draggedItemIDs in
                onInternalDragBegan(draggedItemIDs)
                return draggedItemIDs.map { FolderBrowserDraggedItem(url: $0) }
            }
            .onDragSessionUpdated(onDragSessionUpdated)
            .dropDestination(for: URL.self) { droppedURLs, _ in
                return onDropInCurrentDirectory(droppedURLs)
            }
            .folderBrowserMoveByDefaultDropTarget()
        }
    }

    @ViewBuilder
    private func rowBackgroundView(for item: FolderBrowserItem) -> some View {
        let isSelected = selectedItems.contains(item)
        let isDropTarget = dropTargetItemID == item.id

        Rectangle()
            .fill(
                isDropTarget
                ? Color.accentColor.opacity(0.22)
                : (isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .overlay {
                if isSelected || isDropTarget {
                    Rectangle()
                        .stroke(Color.accentColor.opacity(0.95), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct ListItemView: View {
    let item: FolderBrowserItem
    let isStarred: Bool
    let isSelected: Bool
    let isDropTargeted: Bool
    let showSize: Bool
    let showDate: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            FolderBrowserItemIconView(
                item: item,
                size: 18,
                showStarBadge: isStarred
            )
            .frame(width: 24, height: 24)

            // Name
            Text(item.displayName)
                .font(.system(size: 13))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // File size
            if showSize {
                Text(item.formattedFileSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }

            // Modification date
            if showDate {
                Text(item.formattedModificationDate)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 160, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(
                    isDropTargeted
                    ? Color.accentColor.opacity(0.26)
                    : (isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
                )
        )
        .overlay {
            if isSelected || isDropTargeted {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }
}
