import SwiftUI
import Quartz

struct FolderBrowserView: View {
    private let ownedRoute: BrowserRoute?
    private let externalSession: FolderBrowserSession?
    private let onReturnToParentPage: (() -> Void)?

    init(
        title: String,
        path: String,
        initiallySelectedPath: String? = nil,
        sourceApplicationId: UUID? = nil,
        parentPageTitle: String? = nil,
        onReturnToParentPage: (() -> Void)? = nil
    ) {
        ownedRoute = BrowserRoute(
            title: title,
            path: path,
            initiallySelectedPath: initiallySelectedPath,
            sourceApplicationId: sourceApplicationId,
            parentPageTitle: parentPageTitle
        )
        externalSession = nil
        self.onReturnToParentPage = onReturnToParentPage
    }

    init(session: FolderBrowserSession, onReturnToParentPage: (() -> Void)? = nil) {
        ownedRoute = nil
        externalSession = session
        self.onReturnToParentPage = onReturnToParentPage
    }

    var body: some View {
        Group {
            if let externalSession {
                SessionFolderBrowserContainer(
                    session: externalSession,
                    onReturnToParentPage: onReturnToParentPage
                )
            } else if let ownedRoute {
                OwnedFolderBrowserContainer(
                    initialRoute: ownedRoute,
                    onReturnToParentPage: onReturnToParentPage
                )
            }
        }
    }
}

private struct OwnedFolderBrowserContainer: View {
    @StateObject private var session: FolderBrowserSession
    let onReturnToParentPage: (() -> Void)?

    init(initialRoute: BrowserRoute, onReturnToParentPage: (() -> Void)? = nil) {
        _session = StateObject(wrappedValue: FolderBrowserSession(route: initialRoute))
        self.onReturnToParentPage = onReturnToParentPage
    }

    var body: some View {
        FolderBrowserContentView(
            session: session,
            onReturnToParentPage: onReturnToParentPage
        )
    }
}

private struct SessionFolderBrowserContainer: View {
    @ObservedObject var session: FolderBrowserSession
    let onReturnToParentPage: (() -> Void)?

    var body: some View {
        FolderBrowserContentView(
            session: session,
            onReturnToParentPage: onReturnToParentPage
        )
    }
}

private struct FolderBrowserContentView: View {
    @ObservedObject var session: FolderBrowserSession
    let onReturnToParentPage: (() -> Void)?

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @ObservedObject private var viewModel: FolderBrowserViewModel
    @AppStorage("folderBrowserViewMode") private var viewMode: BrowserViewMode = .grid
    @State private var showingDeleteAlert = false
    @State private var itemsToDelete: [FolderBrowserItem] = []
    @State private var showingRenameAlert = false
    @State private var itemToRename: FolderBrowserItem?
    @State private var renameText = ""
    @State private var errorAlert: ErrorAlert?
    @State private var addFolderPathSheetContext: AddFolderPathSheetContext?
    @State private var activeDragPaths: Set<String> = []
    @State private var activeDraggedURLs: [URL] = []
    @State private var activeDragWasHandledInApp = false
    @State private var gridColumnCount = 1
    @State private var columnViewColumnCount = 1
    @State private var keyboardMonitor: Any?
    @State private var isQuickLookPresented = false
    @FocusState private var isCommandTargetFocused: Bool

    init(session: FolderBrowserSession, onReturnToParentPage: (() -> Void)? = nil) {
        self.session = session
        self.onReturnToParentPage = onReturnToParentPage
        _viewModel = ObservedObject(wrappedValue: session.viewModel)
    }

    private var undoManagerIdentity: ObjectIdentifier? {
        undoManager.map(ObjectIdentifier.init)
    }

    private var starredPaths: Set<String> {
        Set(appState.starredItems.compactMap(\.path))
    }

    private var sourceApplication: Application? {
        guard let sourceApplicationId = session.route.sourceApplicationId else { return nil }
        return appState.applications.first { $0.id == sourceApplicationId }
    }

    private var sortOrderBinding: Binding<SortOrder> {
        Binding(
            get: { session.sortOrder },
            set: { session.updateSortOrder($0) }
        )
    }

    private var commandHandler: FolderBrowserCommandHandler {
        FolderBrowserCommandHandler(
            canCopySelection: { viewModel.canCopySelection },
            canCutSelection: { viewModel.canCutSelection },
            canPaste: { viewModel.canPasteItems() },
            canDuplicateSelection: { viewModel.canDuplicateSelection },
            canTrashSelection: { viewModel.canTrashSelection },
            canRenameSelection: { viewModel.canRenameSelection },
            canOpenSelection: { viewModel.canOpenSelection },
            canQuickLookSelection: { viewModel.canQuickLookSelection },
            canShowInfo: { viewModel.canShowInfoSelection },
            canRevealSelection: { viewModel.canRevealSelection },
            canNavigateBack: { viewModel.canNavigateBack },
            canNavigateForward: { viewModel.canNavigateForward },
            canNavigateUp: { viewModel.canNavigateUp },
            canSelectAll: { viewModel.canSelectAll },
            canDeselectAll: { viewModel.canDeselectAll },
            currentViewMode: { viewMode },
            copySelection: copySelectionToClipboard,
            cutSelection: cutSelectionToClipboard,
            paste: pasteFromClipboard,
            duplicateSelection: duplicateSelectedItems,
            trashSelection: promptDeleteSelection,
            renameSelection: startRenameFromSelection,
            openSelection: openSelectionFromCommand,
            quickLookSelection: toggleQuickLookPreview,
            showInfo: showInfoForSelection,
            revealSelection: revealSelectionInFinder,
            navigateBack: { viewModel.navigateBack() },
            navigateForward: { viewModel.navigateForward() },
            navigateUp: { viewModel.navigateUp() },
            selectAll: { viewModel.selectAll() },
            deselectAll: { viewModel.deselectAll() },
            setViewMode: { viewMode = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            FolderBrowserToolbar(
                viewModel: viewModel,
                viewMode: $viewMode,
                sortOrder: sortOrderBinding
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
        .focusable()
        .focused($isCommandTargetFocused)
        .focusEffectDisabled()
        .focusedSceneValue(\.folderBrowserCommandHandler, commandHandler)
        .navigationTitle(session.route.parentPageTitle == nil ? session.route.title : "")
        .toolbar {
            if session.route.parentPageTitle != nil {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        if let onReturnToParentPage {
                            onReturnToParentPage()
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.headline)

                            Text(session.route.parentPageTitle ?? session.route.title)
                                .font(.headline)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .help("Back to \(session.route.parentPageTitle ?? session.route.title)")
                }
            }
        }
        .onAppear {
            startKeyboardMonitor()
            viewModel.bindUndoManager(undoManager)
            isCommandTargetFocused = true
            if !session.isPlaceholder, viewModel.currentDirectory == nil {
                session.open(session.route)
            }
        }
        .onDisappear {
            stopKeyboardMonitor()
            isQuickLookPresented = false
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
        .sheet(item: $addFolderPathSheetContext) { context in
            AddFolderPathSheet(context: context)
                .environmentObject(appState)
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
                    onInternalDragBegan: handleInternalDragBegan,
                    onDragSessionUpdated: handleDragSessionUpdated
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
                    onInternalDragBegan: handleInternalDragBegan,
                    onDragSessionUpdated: handleDragSessionUpdated
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
                    onInternalDragBegan: handleInternalDragBegan,
                    onDragSessionUpdated: handleDragSessionUpdated
                )
            }
        }
        .quickLookPreview(
            items: viewModel.items,
            selectedItems: $viewModel.selectedItems,
            isPresented: $isQuickLookPresented,
            onArrowNavigation: handleArrowNavigation
        )
        .onKeyPress(.space) {
            guard canHandleFocusedKeyPress, viewModel.canQuickLookSelection else { return .ignored }
            toggleQuickLookPreview()
            return .handled
        }
        .onKeyPress(.return) {
            guard canHandleFocusedKeyPress, viewModel.canOpenSelection else { return .ignored }
            openSelectionFromCommand()
            return .handled
        }
        .onKeyPress(.delete) {
            guard canHandleFocusedKeyPress, viewModel.canTrashSelection else { return .ignored }
            promptDeleteSelection()
            return .handled
        }
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
            clearActiveDragState()
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

                if item.isDirectory {
                    Button(action: {
                        appState.openBrowserRouteInNewTab(
                            BrowserRoute(
                                title: item.displayName,
                                path: item.url.path,
                                sourceApplicationId: session.route.sourceApplicationId,
                                parentPageTitle: session.route.parentPageTitle,
                                parentDetailTarget: session.route.parentDetailTarget
                            )
                        )
                    }) {
                        Label("Open in New Tab", systemImage: "plus.square.on.square")
                    }
                }

                if !item.isDirectory {
                    Button(action: {
                        viewModel.selectItem(item)
                        toggleQuickLookPreview()
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
                viewModel.revealItemsInFinder(items)
            }) {
                Label("Reveal in Finder", systemImage: "folder")
            }

            if items.count == 1, let item = items.first, !item.isDirectory {
                Divider()

                Button("Copy Path") {
                    copyPath(item)
                }
            } else if items.count == 1, let item = items.first, item.isDirectory {
                Divider()

                Button("Copy Path") {
                    copyPath(item)
                }

                Button("Add to Application...") {
                    presentAddFolderPathSheet(
                        for: item,
                        title: "Add Folder Path",
                        preselectedApplicationId: sourceApplication?.id
                    )
                }
            }
        }
    }

    // MARK: - Event Handlers
    private func handleItemMouseDown(_ item: FolderBrowserItem, event: NSEvent) {
        isCommandTargetFocused = true

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
            guard !FolderBrowserCommandSupport.isTextInputActive else { return event }

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
        guard isCommandTargetFocused else { return false }
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
        isCommandTargetFocused = true
        activeDraggedURLs = draggedURLs.map { $0.standardizedFileURL }
        activeDragPaths = Set(activeDraggedURLs.map(\.path))
        activeDragWasHandledInApp = false
    }

    private func handleDragSessionUpdated(_ session: DragSession) {
        switch session.phase {
        case .ended(.move), .ended(.delete):
            let draggedURLs = activeDraggedURLs
            let wasHandledInApp = activeDragWasHandledInApp
            clearActiveDragState()

            guard !wasHandledInApp, !draggedURLs.isEmpty else { return }

            Task {
                do {
                    try await viewModel.finalizeExternalMove(for: draggedURLs)
                } catch {
                    await MainActor.run {
                        errorAlert = ErrorAlert(
                            title: "Move Failed",
                            message: "The drop finished, but Ventry could not remove the original item(s): \(error.localizedDescription)"
                        )
                    }
                }
            }
        case .ended(_), .dataTransferCompleted:
            clearActiveDragState()
        case .initial, .active:
            break
        @unknown default:
            clearActiveDragState()
        }
    }

    private func clearActiveDragState() {
        activeDraggedURLs = []
        activeDragPaths.removeAll()
        activeDragWasHandledInApp = false
    }

    private func handleDropInCurrentDirectory(_ droppedURLs: [URL]) -> Bool {
        guard let currentDirectory = viewModel.currentDirectory else { return false }
        return handleDrop(droppedURLs, onto: currentDirectory)
    }

    private func handleDrop(_ droppedURLs: [URL], onto destinationDirectory: URL) -> Bool {
        guard !droppedURLs.isEmpty else { return false }

        let normalizedURLs = droppedURLs.map { $0.standardizedFileURL }
        activeDragWasHandledInApp = isActiveInternalDrag(normalizedURLs)
        let shouldMove = shouldMoveDroppedItems(normalizedURLs)

        Task {
            do {
                _ = try await viewModel.importDroppedItems(
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
                clearActiveDragState()
            }
        }

        return true
    }

    private func shouldMoveDroppedItems(_ droppedURLs: [URL]) -> Bool {
        let optionCopyRequested = NSEvent.modifierFlags.contains(.option)
        if optionCopyRequested {
            return false
        }

        guard viewModel.currentDirectory != nil else {
            return false
        }

        let droppedPaths = Set(droppedURLs.map { $0.path })
        if !activeDragPaths.isEmpty && droppedPaths.isSubset(of: activeDragPaths) {
            return true
        }

        return true
    }

    private func isActiveInternalDrag(_ droppedURLs: [URL]) -> Bool {
        guard !activeDragPaths.isEmpty else { return false }
        let droppedPaths = Set(droppedURLs.map(\.path))
        return droppedPaths.isSubset(of: activeDragPaths)
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

    private var canHandleFocusedKeyPress: Bool {
        isCommandTargetFocused && !FolderBrowserCommandSupport.isTextInputActive
    }

    private func promptDeleteSelection() {
        let selectedItems = viewModel.orderedSelectedItems
        guard !selectedItems.isEmpty else { return }
        itemsToDelete = selectedItems
        showingDeleteAlert = true
    }

    private func startRename(_ item: FolderBrowserItem) {
        itemToRename = item
        renameText = item.displayName
        showingRenameAlert = true
    }

    private func startRenameFromSelection() {
        guard viewModel.canRenameSelection,
              let item = viewModel.orderedSelectedItems.first else { return }
        startRename(item)
    }

    private func openSelectionFromCommand() {
        guard viewModel.canOpenSelection else { return }
        viewModel.openSelectedItem()
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
        let urls = items.map { $0.url.standardizedFileURL }
        FolderBrowserClipboardController.shared.write(urls: urls, operation: .copy)
    }

    private func copySelectionToClipboard() {
        viewModel.copySelectedItems()
    }

    private func cutSelectionToClipboard() {
        viewModel.cutSelectedItems()
    }

    private func pasteFromClipboard() {
        Task {
            do {
                _ = try await viewModel.pasteItems()
            } catch {
                errorAlert = ErrorAlert(
                    title: "Paste Failed",
                    message: "Could not paste item(s): \(error.localizedDescription)"
                )
            }
        }
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

    private func duplicateSelectedItems() {
        duplicateItems(viewModel.orderedSelectedItems)
    }

    private func showInfo(for items: [FolderBrowserItem]) {
        viewModel.showInfo(for: items)
    }

    private func showInfoForSelection() {
        let selectedItems = viewModel.orderedSelectedItems
        guard !selectedItems.isEmpty else { return }
        showInfo(for: selectedItems)
    }

    private func revealSelectionInFinder() {
        let selectedItems = viewModel.orderedSelectedItems
        guard !selectedItems.isEmpty else { return }
        viewModel.revealItemsInFinder(selectedItems)
    }

    private func toggleQuickLookPreview() {
        guard viewModel.canQuickLookSelection else { return }
        isQuickLookPresented.toggle()
    }

    private func copyPath(_ item: FolderBrowserItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }

    private func presentAddFolderPathSheet(
        for item: FolderBrowserItem,
        title: String,
        preselectedApplicationId: UUID?
    ) {
        guard item.isDirectory else { return }

        addFolderPathSheetContext = AddFolderPathSheetContext(
            folderURL: item.url.standardizedFileURL,
            title: title,
            preselectedApplicationId: preselectedApplicationId
        )
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

private struct AddFolderPathSheetContext: Identifiable {
    let id = UUID()
    let folderURL: URL
    let title: String
    let preselectedApplicationId: UUID?
}

private struct AddFolderPathSheet: View {
    let context: AddFolderPathSheetContext

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedApplicationId: UUID?
    @State private var directoryName: String
    @State private var directoryPath: String
    @State private var selectedType: DirectoryType = .other
    @State private var errorMessage: String?

    init(context: AddFolderPathSheetContext) {
        self.context = context
        let normalizedURL = context.folderURL.standardizedFileURL
        _selectedApplicationId = State(initialValue: context.preselectedApplicationId)
        _directoryName = State(initialValue: normalizedURL.lastPathComponent)
        _directoryPath = State(initialValue: normalizedURL.path)
    }

    private var availableApplications: [Application] {
        appState.applications
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedApplication: Application? {
        guard let selectedApplicationId else { return nil }
        return availableApplications.first { $0.id == selectedApplicationId }
    }

    private var isSaveDisabled: Bool {
        directoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || directoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedApplication == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Text(context.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Add") {
                    saveFolderPath()
                }
                .buttonStyle(.plain)
                .disabled(isSaveDisabled)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Folder Path")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Application")
                                .font(.subheadline)

                            if availableApplications.isEmpty {
                                Text("No applications are available. Add an application to Ventry first.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("Application", selection: $selectedApplicationId) {
                                    Label("Select an application", systemImage: "app")
                                        .tag(UUID?.none)
                                    ForEach(availableApplications) { application in
                                        ApplicationPickerOptionView(application: application)
                                            .tag(Optional(application.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directory Name")
                                .font(.subheadline)

                            TextField("Enter directory name", text: $directoryName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.subheadline)

                            Picker("Type", selection: $selectedType) {
                                ForEach(DirectoryType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.systemImage)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Directory Path")
                                .font(.subheadline)

                            TextField("Directory path", text: $directoryPath)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .background(Color(.windowBackgroundColor))
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 640, minHeight: 360, idealHeight: 420, maxHeight: 520)
        .alert(
            "Could Not Add Folder Path",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { shouldShow in
                    if !shouldShow {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveFolderPath() {
        guard let application = selectedApplication else {
            errorMessage = "Choose an application before adding this folder path."
            return
        }

        let normalizedPath = URL(fileURLWithPath: directoryPath).standardizedFileURL.path
        let duplicateExists = application.directories.contains {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path == normalizedPath
        }

        guard !duplicateExists else {
            errorMessage = "This application already tracks \(normalizedPath)."
            return
        }

        let trimmedName = directoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Directory name cannot be empty."
            return
        }

        let directory = AppDirectory(
            name: trimmedName,
            path: normalizedPath,
            type: selectedType
        )

        appState.addCustomDirectory(for: application, directory: directory)
        dismiss()
    }
}

private struct ApplicationPickerOptionView: View {
    let application: Application

    var body: some View {
        HStack(spacing: 8) {
            if let bundlePath = application.bundlePath,
               let icon = AppLoader.shared.getAppIcon(for: bundlePath) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
            } else {
                Image(systemName: "app")
                    .frame(width: 16, height: 16)
                    .foregroundColor(.secondary)
            }

            Text(application.name)
        }
    }
}
