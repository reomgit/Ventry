import SwiftUI

struct FolderBrowserView: View {
    let title: String
    let path: String

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
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            viewModel.refresh()
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
            if viewModel.currentDirectory == nil {
                let url = URL(fileURLWithPath: path)
                viewModel.navigateTo(url: url)
            }
        }
        .onChange(of: path) { _, newPath in
            let url = URL(fileURLWithPath: newPath)
            viewModel.navigateTo(url: url)
        }
        .alert("Delete Items", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                itemsToDelete = []
            }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            Text("Are you sure you want to delete \(itemsToDelete.count) item(s)? This action cannot be undone.")
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
                    selectedItems: $viewModel.selectedItems,
                    onItemMouseDown: handleItemMouseDown,
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
                    selectedItems: $viewModel.selectedItems,
                    onItemMouseDown: handleItemMouseDown,
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
            handleArrowNavigation(step: -1)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            handleArrowNavigation(step: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            handleArrowNavigation(step: 1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            handleArrowNavigation(step: 1)
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

    private func handleArrowNavigation(step: Int) {
        viewModel.moveSelection(by: step)
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
        let fileManager = FileManager.default

        Task {
            for item in items {
                do {
                    let parentURL = item.url.deletingLastPathComponent()
                    let baseName = item.url.deletingPathExtension().lastPathComponent
                    let ext = item.url.pathExtension
                    var counter = 1
                    var newURL: URL

                    repeat {
                        let newName = ext.isEmpty ? "\(baseName) copy \(counter)" : "\(baseName) copy \(counter).\(ext)"
                        newURL = parentURL.appendingPathComponent(newName)
                        counter += 1
                    } while fileManager.fileExists(atPath: newURL.path)

                    try fileManager.copyItem(at: item.url, to: newURL)
                } catch {
                    await MainActor.run {
                        errorAlert = ErrorAlert(
                            title: "Duplicate Failed",
                            message: "Could not duplicate '\(item.displayName)': \(error.localizedDescription)"
                        )
                    }
                }
            }

            await MainActor.run {
                viewModel.refresh()
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
}

// MARK: - Error Alert
private struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
