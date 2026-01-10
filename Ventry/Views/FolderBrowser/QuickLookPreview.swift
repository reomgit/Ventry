import SwiftUI
import Quartz

/// Quick Look preview panel wrapper for SwiftUI
struct QuickLookPreview: NSViewRepresentable {
    let urls: [URL]
    @Binding var isPresented: Bool

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
        let coordinator = QuickLookCoordinator(urls: urls, isPresented: $isPresented)
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

    init(urls: [URL], isPresented: Binding<Bool>) {
        self.urls = urls
        self._isPresented = isPresented
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
        // Allow the panel to handle events
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
    @State private var showPreview = false

    func body(content: Content) -> some View {
        content
            .background(
                QuickLookPreview(
                    urls: Array(selectedItems).map { $0.url },
                    isPresented: $showPreview
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
        selectedItems: Binding<Set<FolderBrowserItem>>
    ) -> some View {
        modifier(QuickLookModifier(items: items, selectedItems: selectedItems))
    }
}
