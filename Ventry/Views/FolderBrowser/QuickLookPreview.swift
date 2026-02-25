import SwiftUI
import Quartz

/// Quick Look preview panel wrapper for SwiftUI
struct QuickLookPreview: NSViewRepresentable {
    let urls: [URL]
    @Binding var isPresented: Bool
    let onArrowNavigation: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            DispatchQueue.main.async {
                showQuickLook(from: nsView)
            }
        }
    }

    private func showQuickLook(from view: NSView) {
        guard view.window != nil else { return }

        // Get or create the Quick Look panel
        guard let panel = QLPreviewPanel.shared() else { return }

        // Always update the coordinator with latest URLs
        let coordinator = QuickLookCoordinator(
            urls: urls,
            isPresented: $isPresented,
            onArrowNavigation: onArrowNavigation
        )
        panel.dataSource = coordinator
        panel.delegate = coordinator

        // Keep coordinator alive
        objc_setAssociatedObject(panel, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)

        // Show or update the panel
        if !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            panel.center()
        } else {
            // If panel is already visible, reload data to show updated selection
            panel.reloadData()
        }
    }
}

/// Coordinator to handle Quick Look data source and delegate
class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let urls: [URL]
    @Binding var isPresented: Bool
    let onArrowNavigation: (Int) -> Void

    init(
        urls: [URL],
        isPresented: Binding<Bool>,
        onArrowNavigation: @escaping (Int) -> Void
    ) {
        self.urls = urls
        self._isPresented = isPresented
        self.onArrowNavigation = onArrowNavigation
        super.init()
    }

    // MARK: - QLPreviewPanelDataSource
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return urls[index] as QLPreviewItem
    }

    // MARK: - QLPreviewPanelDelegate
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let event else { return false }
        guard event.type == .keyDown else { return false }

        // Keep existing Quick Look behavior for explicit multi-select previews.
        guard urls.count <= 1 else { return false }
        guard !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.option),
              !event.modifierFlags.contains(.control) else {
            return false
        }

        switch Int(event.keyCode) {
        case 123, 126: // Left / Up
            onArrowNavigation(-1)
            return true
        case 124, 125: // Right / Down
            onArrowNavigation(1)
            return true
        default:
            break
        }

        return false
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        // Return zero rect to let Quick Look choose its own position
        return .zero
    }

    func previewPanelDidClose(_ panel: QLPreviewPanel!) {
        isPresented = false
    }
}

/// View modifier to enable Quick Look preview with spacebar
struct QuickLookModifier: ViewModifier {
    let items: [FolderBrowserItem]
    @Binding var selectedItems: Set<FolderBrowserItem>
    let onArrowNavigation: (Int) -> Void
    @State private var showPreview = false

    private var orderedSelectedURLs: [URL] {
        items
            .filter { selectedItems.contains($0) }
            .map(\.url)
    }

    func body(content: Content) -> some View {
        content
            .background(
                QuickLookPreview(
                    urls: orderedSelectedURLs,
                    isPresented: $showPreview,
                    onArrowNavigation: onArrowNavigation
                )
                .frame(width: 0, height: 0)
                .opacity(0)
            )
            .onKeyPress(.space) {
                if !selectedItems.isEmpty {
                    showPreview.toggle()
                }
                return .handled
            }
    }
}

extension View {
    func quickLookPreview(
        items: [FolderBrowserItem],
        selectedItems: Binding<Set<FolderBrowserItem>>,
        onArrowNavigation: @escaping (Int) -> Void = { _ in }
    ) -> some View {
        modifier(
            QuickLookModifier(
                items: items,
                selectedItems: selectedItems,
                onArrowNavigation: onArrowNavigation
            )
        )
    }
}
