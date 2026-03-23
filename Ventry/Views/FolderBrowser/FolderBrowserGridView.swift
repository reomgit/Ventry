import SwiftUI

struct FolderBrowserGridView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    let starredPaths: Set<String>
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemMouseDown: (FolderBrowserItem, NSEvent) -> Void
    let onColumnCountChange: (Int) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu
    let onDropOnItem: ([URL], FolderBrowserItem) -> Bool
    let onDropInCurrentDirectory: ([URL]) -> Bool
    let onInternalDragBegan: ([URL]) -> Void
    let onDragSessionUpdated: (DragSession) -> Void

    @State private var hoveredItem: FolderBrowserItem?
    @State private var dropTargetItemID: UUID?
    @Namespace private var dragContainerNamespace

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 760
            let columns = responsiveColumns(for: geometry.size.width, compact: isCompact)
            let columnCount = calculatedColumnCount(for: geometry.size.width, compact: isCompact)

            ScrollView {
                LazyVGrid(columns: columns, spacing: isCompact ? 12 : 16) {
                    ForEach(items) { item in
                        GridItemView(
                            item: item,
                            isStarred: starredPaths.contains(item.url.standardizedFileURL.path),
                            isSelected: selectedItems.contains(item),
                            isHovered: hoveredItem == item,
                            isDropTargeted: dropTargetItemID == item.id,
                            isCompact: isCompact
                        )
                        .overlay {
                            MouseEventCaptureView { event in
                                onItemMouseDown(item, event)
                            }
                        }
                        .onHover { hovering in
                            hoveredItem = hovering ? item : nil
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
                .padding(isCompact ? 10 : 16)
            }
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
            .onAppear {
                onColumnCountChange(columnCount)
            }
            .onChange(of: columnCount) { _, newColumnCount in
                onColumnCountChange(newColumnCount)
            }
        }
    }

    private func responsiveColumns(for width: CGFloat, compact: Bool) -> [GridItem] {
        let minimum: CGFloat = compact ? 92 : 110
        let maximum: CGFloat = compact ? 120 : 140
        return [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: compact ? 12 : 16)]
    }

    private func calculatedColumnCount(for width: CGFloat, compact: Bool) -> Int {
        let minimum: CGFloat = compact ? 92 : 110
        let spacing: CGFloat = compact ? 12 : 16
        let horizontalPadding: CGFloat = compact ? 10 : 16
        let contentWidth = max(width - (horizontalPadding * 2), minimum)
        return max(1, Int((contentWidth + spacing) / (minimum + spacing)))
    }
}

private struct GridItemView: View {
    let item: FolderBrowserItem
    let isStarred: Bool
    let isSelected: Bool
    let isHovered: Bool
    let isDropTargeted: Bool
    let isCompact: Bool

    var body: some View {
        let iconFrame: CGFloat = isCompact ? 68 : 80
        let iconSize: CGFloat = isCompact ? 34 : 40
        let tileWidth: CGFloat = isCompact ? 92 : 100
        let tileHeight: CGFloat = isCompact ? 108 : 120

        VStack(spacing: isCompact ? 4 : 6) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isDropTargeted
                        ? Color.accentColor.opacity(0.2)
                        : (isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .frame(width: iconFrame, height: iconFrame)

                FolderBrowserItemIconView(
                    item: item,
                    size: iconSize,
                    showCreativeBadge: true,
                    showStarBadge: isStarred
                )
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
                .font(.system(size: isCompact ? 10 : 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(width: tileWidth)
                .padding(.horizontal, 4)
        }
        .frame(width: tileWidth, height: tileHeight)
    }
}
