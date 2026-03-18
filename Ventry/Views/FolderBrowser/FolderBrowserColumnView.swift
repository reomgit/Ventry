import SwiftUI

struct FolderBrowserColumnView<ContextMenu: View>: View {
    let items: [FolderBrowserItem]
    let starredPaths: Set<String>
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemMouseDown: (FolderBrowserItem, NSEvent) -> Void
    let onColumnCountChange: (Int) -> Void
    let contextMenuBuilder: ([FolderBrowserItem]) -> ContextMenu
    let onDropOnItem: ([URL], FolderBrowserItem) -> Bool
    let onDropInCurrentDirectory: ([URL]) -> Bool
    let onInternalDragBegan: ([URL]) -> Void

    @State private var dropTargetItemID: UUID?
    @Namespace private var dragContainerNamespace

    var body: some View {
        GeometryReader { geometry in
            let columnCount = calculatedColumnCount(for: geometry.size.width)
            let columns = responsiveColumns(for: columnCount)
            let compact = geometry.size.width < 720

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: compact ? 8 : 12) {
                    ForEach(items) { item in
                        ColumnItemView(
                            item: item,
                            isStarred: starredPaths.contains(item.url.standardizedFileURL.path),
                            isSelected: selectedItems.contains(item),
                            isDropTargeted: dropTargetItemID == item.id,
                            compact: compact
                        )
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
                .padding(compact ? 10 : 14)
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
            .onAppear {
                onColumnCountChange(columnCount)
            }
            .onChange(of: columnCount) { _, newColumnCount in
                onColumnCountChange(newColumnCount)
            }
        }
    }

    private func calculatedColumnCount(for width: CGFloat) -> Int {
        if width < 620 {
            return 1
        } else if width < 940 {
            return 2
        } else if width < 1260 {
            return 3
        } else {
            return 4
        }
    }

    private func responsiveColumns(for count: Int) -> [GridItem] {
        return Array(repeating: GridItem(.flexible(minimum: 150), spacing: 16), count: count)
    }
}

private struct ColumnItemView: View {
    let item: FolderBrowserItem
    let isStarred: Bool
    let isSelected: Bool
    let isDropTargeted: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            FolderBrowserItemIconView(
                item: item,
                size: compact ? 14 : 16,
                showStarBadge: isStarred
            )
            .frame(width: compact ? 18 : 20, height: compact ? 18 : 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: compact ? 11 : 12))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text(item.formattedFileSize)
                        .font(.system(size: compact ? 9 : 10))
                        .foregroundColor(.secondary)

                    if !item.isDirectory {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)

                        Text(item.formattedModificationDate)
                            .font(.system(size: compact ? 9 : 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 5 : 6)
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
