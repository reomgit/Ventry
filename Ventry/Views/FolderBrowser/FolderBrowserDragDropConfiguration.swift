import SwiftUI

private let folderBrowserDragConfiguration = DragConfiguration(
    operationsWithinApp: .init(allowCopy: true, allowMove: true, allowDelete: false),
    operationsOutsideApp: .init(allowCopy: true, allowMove: true, allowDelete: true)
)

private func folderBrowserPreferredDropOperation() -> DropOperation {
    NSEvent.modifierFlags.contains(.option) ? .copy : .move
}

extension View {
    func folderBrowserMoveByDefaultDragSource() -> some View {
        dragConfiguration(folderBrowserDragConfiguration)
    }

    func folderBrowserMoveByDefaultDropTarget() -> some View {
        dropConfiguration { _ in
            DropConfiguration(operation: folderBrowserPreferredDropOperation())
        }
    }
}
