import SwiftUI

struct FolderBrowserGridView: View {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onItemDoubleClick: (FolderBrowserItem) -> Void
    let onItemClick: (FolderBrowserItem, _ isCommandKey: Bool) -> Void

    @State private var hoveredItem: FolderBrowserItem?

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
                        isHovered: hoveredItem == item
                    )
                    .onTapGesture(count: 2) {
                        onItemDoubleClick(item)
                    }
                    .onTapGesture {
                        let commandPressed = NSEvent.modifierFlags.contains(.command)
                        onItemClick(item, commandPressed)
                    }
                    .onHover { hovering in
                        hoveredItem = hovering ? item : nil
                    }
                }
            }
            .padding()
        }
    }
}

private struct GridItemView: View {
    let item: FolderBrowserItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    .frame(width: 80, height: 80)

                Image(systemName: item.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(item.iconColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
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
