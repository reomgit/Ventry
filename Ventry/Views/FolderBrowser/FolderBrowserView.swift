import SwiftUI
import Quartz

struct FolderBrowserView: View {
    let title: String
    let path: String
    var initiallySelectedPath: String? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.undoManager) private var undoManager
    @StateObject private var viewModel = FolderBrowserViewModel()
    @AppStorage("folderBrowserViewMode") private var viewMode: BrowserViewMode = .grid
    @State private var sortOrder: SortOrder = .nameAscending
    @State private var showingDeleteAlert = false
    @State private var itemsToDelete: [FolderBrowserItem] = []
    @State private var showingRenameAlert = false
    @State private var itemToRename: FolderBrowserItem?
    @State private var renameText = ""
    @State private var errorAlert: ErrorAlert?
    @State private var activeDragPaths: Set<String> = []
    @State private var gridColumnCount = 1
    @State private var columnViewColumnCount = 1
    @State private var keyboardMonitor: Any?

    private var undoManagerIdentity: ObjectIdentifier? {
        undoManager.map(ObjectIdentifier.init)
    }

    private var starredPaths: Set<String> {
        Set(appState.starredItems.compactMap(\.path))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            FolderBrowserToolbar(
                viewModel: viewModel,
                viewMode: $viewMode,
                sortOrder: $sortOrder
            )

            Divider()

            // Content area
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if viewModel.isBlockedByDocumentsPrivacy {
                    VStack(spacing: 14) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Ventry Can't Access Documents")
                            .font(.headline)

                        Text("macOS is blocking access to Documents. Ventry needs this to create and manage Documents/Ventry/Design Assets.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Enable Ventry in System Settings > Privacy & Security > Files & Folders. If Documents access still does not appear there, Full Disk Access is the fallback.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Try Again") {
                                viewModel.requestPermissionAndRefresh()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Open Privacy Settings") {
                                viewModel.openPrivacySettings()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            if viewModel.requiresPermission {
                                viewModel.requestPermissionAndRefresh()
                            } else {
                                viewModel.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("This folder is empty")
                            .foregroundColor(.secondary)
                    }
                } else {
                    contentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(title)
        .onAppear {
            startKeyboardMonitor()
            viewModel.bindUndoManager(undoManager)
            if viewModel.currentDirectory == nil {
                let url = URL(fileURLWithPath: path)
                viewModel.navigateTo(url: url, selectingPath: initiallySelectedPath)
            }
        }
        .onDisappear {
            stopKeyboardMonitor()
        }
        .onChange(of: path) { _, newPath in
            let url = URL(fileURLWithPath: newPath)
            viewModel.navigateTo(url: url, selectingPath: initiallySelectedPath)
        }
        .onChange(of: undoManagerIdentity) { _, _ in
            viewModel.bindUndoManager(undoManager)
        }
        .onChange(of: viewModel.operationErrorMessage) { _, message in
            guard let message else { return }
            errorAlert = ErrorAlert(
                title: "Operation Failed",
                message: message
            )
            viewModel.clearOperationErrorMessage()
        }
        .alert("Delete Items", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                itemsToDelete = []
            }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            Text("Are you sure you want to delete \(itemsToDelete.count) item(s)? You can undo this action.")
        }
        .alert("Rename Item", isPresented: $showingRenameAlert) {
            TextField("New Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                itemToRename = nil
                renameText = ""
            }
            Button("Rename") {
                performRename()
            }
        } message: {
            Text("Enter a new name for '\(itemToRename?.displayName ?? "")'")
        }
        .alert(item: $errorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch viewMode {
            case .grid:
                FolderBrowserGridView(
                    items: viewModel.items,
                    starredPaths: starredPaths,
                    selectedItems: $viewModel.selectedItems,
                    onItemMouseDown: handleItemMouseDown,
                    onColumnCountChange: { columnCount in
                        gridColumnCount = max(1, columnCount)
                    },
                    contextMenuBuilder: contextMenuContent,
                    onDropOnItem: { droppedURLs, item in
                        handleDrop(droppedURLs, onto: item.url)
                    },
                    onDropInCurrentDirectory: handleDropInCurrentDirectory,
                    onInternalDragBegan: handleInternalDragBegan
                )
            case .list:
                FolderBrowserListView(
                    items: viewModel.items,
                    starredPaths: starredPaths,
                    selectedItems: $viewModel.selectedItems,
                    onItemMouseDown: handleItemMouseDown,
                    contextMenuBuilder: contextMenuContent,
                    onDropOnItem: { droppedURLs, item in
                        handleDrop(droppedURLs, onto: item.url)
                    },
                    onDropInCurrentDirectory: handleDropInCurrentDirectory,
                    onInternalDragBegan: handleInternalDragBegan
                )
            case .column:
                FolderBrowserColumnView(
                    items: viewModel.items,
                    starredPaths: starredPaths,
                    selectedItems: $viewModel.selectedItems,
                    onItemMouseDown: handleItemMouseDown,
                    onColumnCountChange: { columnCount in
                        columnViewColumnCount = max(1, columnCount)
                    },
                    contextMenuBuilder: contextMenuContent,
                    onDropOnItem: { droppedURLs, item in
                        handleDrop(droppedURLs, onto: item.url)
                    },
                    onDropInCurrentDirectory: handleDropInCurrentDirectory,
                    onInternalDragBegan: handleInternalDragBegan
                )
            }
        }
        .quickLookPreview(
            items: viewModel.items,
            selectedItems: $viewModel.selectedItems,
            onArrowNavigation: handleArrowNavigation
        )
        .background(
            Group {
                // Delete key shortcut
                Button(action: { handleDeleteKeyPress() }) {
                    EmptyView()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .hidden()

                // Return/Enter key shortcut (default action)
                Button(action: { handleReturnKeyPress() }) {
                    EmptyView()
                }
                .keyboardShortcut(.defaultAction)
                .hidden()

                // Command-A (Select All)
                Button(action: { viewModel.selectAll() }) {
                    EmptyView()
                }
                .keyboardShortcut("a", modifiers: [.command])
                .hidden()
            }
        )
        .onKeyPress(.upArrow) {
            guard viewModel.selectedItems.isEmpty else { return .ignored }
            handleArrowNavigation(.up)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard viewModel.selectedItems.isEmpty else { return .ignored }
            handleArrowNavigation(.left)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard viewModel.selectedItems.isEmpty else { return .ignored }
            handleArrowNavigation(.down)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard viewModel.selectedItems.isEmpty else { return .ignored }
            handleArrowNavigation(.right)
            return .handled
        }
        .onDisappear {
            activeDragPaths.removeAll()
        }
    }

    @ViewBuilder
    func contextMenuContent(for items: [FolderBrowserItem]) -> some View {
        if items.isEmpty {
            EmptyView()
        } else {
            if items.count == 1, let item = items.first {
                Button(action: {
                    viewModel.openFile(item: item)
                }) {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }

                if !item.isDirectory {
                    Button(action: {
                        viewModel.selectItem(item)
                        // Trigger Quick Look via spacebar simulation
                    }) {
                        Label("Quick Look", systemImage: "eye")
                    }
                }

                Divider()
            }

            Button(action: {
                showInfo(for: items)
            }) {
                Label("Get Info", systemImage: "info.circle")
            }

            Divider()

            if items.count == 1 {
                Button(action: {
                    startRename(items[0])
                }) {
                    Label("Rename...", systemImage: "pencil")
                }
            }

            Button(action: {
                copyItems(items)
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(action: {
                duplicateItems(items)
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Divider()

            if items.allSatisfy({ appState.isStarred($0) }) {
                Button(action: {
                    removeFromStarred(items)
                }) {
                    Label(
                        items.count == 1 ? "Remove from Starred" : "Remove \(items.count) from Starred",
                        systemImage: "star.slash"
                    )
                }
            } else {
                Button(action: {
                    addToStarred(items)
                }) {
                    Label(
                        items.count == 1 ? "Add to Starred" : "Add \(items.count) to Starred",
                        systemImage: "star"
                    )
                }
            }

            Divider()

            Button(action: {
                itemsToDelete = items
                showingDeleteAlert = true
            }) {
                Label("Move to Trash", systemImage: "trash")
            }

            Divider()

            Button(action: {
                items.forEach { viewModel.revealInFinder(item: $0) }
            }) {
                Label("Reveal in Finder", systemImage: "folder")
            }

            if items.count == 1, let item = items.first, !item.isDirectory {
                Divider()

                Button("Copy Path") {
                    copyPath(item)
                }
            }
        }
    }

    // MARK: - Event Handlers
    private func handleItemMouseDown(_ item: FolderBrowserItem, event: NSEvent) {
        if event.clickCount == 2 {
            if !viewModel.selectedItems.contains(item) {
                viewModel.selectItem(item)
            }
            handleItemDoubleClick(item)
            return
        }

        let isCommand = event.modifierFlags.contains(.command)
        let isShift = event.modifierFlags.contains(.shift)

        if isShift {
            viewModel.selectRange(to: item, additive: isCommand)
            return
        }

        if isCommand {
            viewModel.toggleSelection(item)
            return
        }

        if viewModel.selectedItems.contains(item), viewModel.selectedItems.count > 1 {
            // Keep multiselection intact so drag can begin from any selected item.
            return
        }

        viewModel.selectItem(item)
    }

    private func handleItemDoubleClick(_ item: FolderBrowserItem) {
        viewModel.openFile(item: item)
    }

    private func handleDeleteKeyPress() {
        guard !viewModel.selectedItems.isEmpty else { return }
        itemsToDelete = Array(viewModel.selectedItems)
        showingDeleteAlert = true
    }

    private func handleReturnKeyPress() {
        guard let item = viewModel.selectedItems.first,
              viewModel.selectedItems.count == 1 else { return }
        viewModel.openFile(item: item)
    }

    private func handleArrowNavigation(_ direction: ArrowNavigationDirection) {
        switch viewMode {
        case .grid:
            switch direction {
            case .left:
                viewModel.moveSelection(by: -1)
            case .right:
                viewModel.moveSelection(by: 1)
            case .up:
                viewModel.moveSelection(by: -gridColumnCount)
            case .down:
                viewModel.moveSelection(by: gridColumnCount)
            }
        case .column:
            switch direction {
            case .left:
                viewModel.moveSelection(by: -1)
            case .right:
                viewModel.moveSelection(by: 1)
            case .up:
                viewModel.moveSelection(by: -columnViewColumnCount)
            case .down:
                viewModel.moveSelection(by: columnViewColumnCount)
            }
        case .list:
            switch direction {
            case .up:
                viewModel.moveSelection(by: -1)
            case .down:
                viewModel.moveSelection(by: 1)
            case .left, .right:
                break
            }
        }
    }

    private func startKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard shouldHandleArrowEvent(event) else { return event }

            switch Int(event.keyCode) {
            case 123:
                handleArrowNavigation(.left)
                return nil
            case 124:
                handleArrowNavigation(.right)
                return nil
            case 125:
                handleArrowNavigation(.down)
                return nil
            case 126:
                handleArrowNavigation(.up)
                return nil
            default:
                return event
            }
        }
    }

    private func stopKeyboardMonitor() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    private func shouldHandleArrowEvent(_ event: NSEvent) -> Bool {
        guard !viewModel.selectedItems.isEmpty else { return false }

        // Let Quick Look keep native arrow key behavior while it is visible.
        if QLPreviewPanel.sharedPreviewPanelExists(),
           let panel = QLPreviewPanel.shared(),
           panel.isVisible {
            return false
        }

        guard !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.option),
              !event.modifierFlags.contains(.control),
              !event.modifierFlags.contains(.shift) else {
            return false
        }

        guard let window = event.window else { return false }
        if window.firstResponder is NSTextView {
            return false
        }

        return [123, 124, 125, 126].contains(Int(event.keyCode))
    }

    private func handleInternalDragBegan(_ draggedURLs: [URL]) {
        activeDragPaths = Set(draggedURLs.map { $0.standardizedFileURL.path })
    }

    private func handleDropInCurrentDirectory(_ droppedURLs: [URL]) -> Bool {
        guard let currentDirectory = viewModel.currentDirectory else { return false }
        return handleDrop(droppedURLs, onto: currentDirectory)
    }

    private func handleDrop(_ droppedURLs: [URL], onto destinationDirectory: URL) -> Bool {
        guard !droppedURLs.isEmpty else { return false }

        let normalizedURLs = droppedURLs.map { $0.standardizedFileURL }
        let shouldMove = shouldMoveDroppedItems(normalizedURLs)

        Task {
            do {
                try await viewModel.importDroppedItems(
                    normalizedURLs,
                    to: destinationDirectory,
                    preferMove: shouldMove
                )
            } catch {
                await MainActor.run {
                    errorAlert = ErrorAlert(
                        title: "Drop Failed",
                        message: "Could not complete the drop: \(error.localizedDescription)"
                    )
                }
            }

            await MainActor.run {
                activeDragPaths.removeAll()
            }
        }

        return true
    }

    private func shouldMoveDroppedItems(_ droppedURLs: [URL]) -> Bool {
        let optionCopyRequested = NSEvent.modifierFlags.contains(.option)
        if optionCopyRequested {
            return false
        }

        guard let currentDirectory = viewModel.currentDirectory?.standardizedFileURL else {
            return false
        }

        let droppedPaths = Set(droppedURLs.map { $0.path })
        if !activeDragPaths.isEmpty && droppedPaths.isSubset(of: activeDragPaths) {
            return true
        }

        return droppedURLs.allSatisfy {
            $0.deletingLastPathComponent().standardizedFileURL == currentDirectory
        }
    }

    // MARK: - File Operations
    private func deleteSelectedItems() {
        Task {
            do {
                try await viewModel.deleteItems(itemsToDelete)
                itemsToDelete = []
            } catch {
                errorAlert = ErrorAlert(
                    title: "Delete Failed",
                    message: "Could not delete items: \(error.localizedDescription)"
                )
            }
        }
    }

    private func startRename(_ item: FolderBrowserItem) {
        itemToRename = item
        renameText = item.displayName
        showingRenameAlert = true
    }

    private func performRename() {
        guard let item = itemToRename, !renameText.isEmpty else { return }

        Task {
            do {
                try await viewModel.renameItem(item, to: renameText)
                itemToRename = nil
                renameText = ""
            } catch {
                errorAlert = ErrorAlert(
                    title: "Rename Failed",
                    message: "Could not rename item: \(error.localizedDescription)"
                )
            }
        }
    }

    private func copyItems(_ items: [FolderBrowserItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
    }

    private func duplicateItems(_ items: [FolderBrowserItem]) {
        Task {
            do {
                try await viewModel.duplicateItems(items)
            } catch {
                errorAlert = ErrorAlert(
                    title: "Duplicate Failed",
                    message: "Could not duplicate selected item(s): \(error.localizedDescription)"
                )
            }
        }
    }

    private func showInfo(for items: [FolderBrowserItem]) {
        // Open Finder's Get Info window using AppleScript
        items.forEach { item in
            let posixPath = item.url.path
            let script = """
            tell application "Finder"
                activate
                set itemPath to POSIX file "\(posixPath)"
                open information window of itemPath
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    // Fallback to revealing in Finder if AppleScript fails
                    print("AppleScript error: \(error)")
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
            } else {
                // Fallback to revealing in Finder
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }

    private func copyPath(_ item: FolderBrowserItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }

    private func addToStarred(_ items: [FolderBrowserItem]) {
        do {
            try appState.addStarredItems(items)
        } catch {
            errorAlert = ErrorAlert(
                title: "Could Not Save Starred Items",
                message: "Ventry could not save starred items to \(AppStorageManager.shared.starredItemsStorageURL.path): \(error.localizedDescription)"
            )
        }
    }

    private func removeFromStarred(_ items: [FolderBrowserItem]) {
        do {
            try appState.removeStarredItems(items)
        } catch {
            errorAlert = ErrorAlert(
                title: "Could Not Update Starred Items",
                message: "Ventry could not update \(AppStorageManager.shared.starredItemsStorageURL.path): \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Error Alert
private struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
