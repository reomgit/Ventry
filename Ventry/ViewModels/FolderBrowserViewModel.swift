import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
class FolderBrowserViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [FolderBrowserItem] = []
    @Published var selectedItems: Set<FolderBrowserItem> = []
    @Published var errorMessage: String?
    @Published var operationErrorMessage: String?
    @Published var requiresPermission = false
    @Published var isBlockedByDocumentsPrivacy = false
    @Published var pendingPermissionPath: String?
    @Published var isLoading = false
    @Published var sortOrder: SortOrder = .nameAscending
    @Published var showHiddenFiles = false
    private var lastSelectedURL: URL?
    private var pendingSelectionPath: String?

    // Navigation state
    @Published var navigationHistory: [URL] = []
    @Published var currentHistoryIndex: Int = -1

    var currentDirectory: URL? {
        guard currentHistoryIndex >= 0 && currentHistoryIndex < navigationHistory.count else {
            return nil
        }
        return navigationHistory[currentHistoryIndex]
    }

    var orderedSelectedItems: [FolderBrowserItem] {
        items.filter { selectedItems.contains($0) }
    }

    var canNavigateBack: Bool {
        currentHistoryIndex > 0
    }

    var canNavigateForward: Bool {
        currentHistoryIndex < navigationHistory.count - 1
    }

    var canNavigateUp: Bool {
        guard let currentDirectory else { return false }
        let parent = currentDirectory.deletingLastPathComponent()
        return parent.path != currentDirectory.path
    }

    var canCopySelection: Bool {
        !orderedSelectedItems.isEmpty
    }

    var canCutSelection: Bool {
        canCopySelection
    }

    var canDuplicateSelection: Bool {
        canCopySelection
    }

    var canTrashSelection: Bool {
        canCopySelection
    }

    var canRenameSelection: Bool {
        orderedSelectedItems.count == 1
    }

    var canOpenSelection: Bool {
        orderedSelectedItems.count == 1
    }

    var canQuickLookSelection: Bool {
        !orderedSelectedItems.isEmpty && orderedSelectedItems.allSatisfy { !$0.isDirectory }
    }

    var canShowInfoSelection: Bool {
        !orderedSelectedItems.isEmpty
    }

    var canRevealSelection: Bool {
        !orderedSelectedItems.isEmpty
    }

    var canSelectAll: Bool {
        !items.isEmpty && selectedItems.count < items.count
    }

    var canDeselectAll: Bool {
        !selectedItems.isEmpty
    }

    // MARK: - Private Properties
    private var loadTask: Task<Void, Never>?
    private let fileManager = FileManager.default
    private let permissionManager = PermissionManager.shared
    private weak var undoManager: UndoManager?

    // MARK: - Initialization
    init() {}

    // MARK: - Undo Manager
    func bindUndoManager(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
        self.undoManager?.levelsOfUndo = 50
    }

    func clearOperationErrorMessage() {
        operationErrorMessage = nil
    }

    // MARK: - Navigation Methods
    func navigateTo(url: URL, addToHistory: Bool = true, selectingPath: String? = nil) {
        loadTask?.cancel()
        pendingSelectionPath = selectingPath.map { URL(fileURLWithPath: $0).standardizedFileURL.path }

        if addToHistory {
            // Remove any forward history when navigating to a new location
            if currentHistoryIndex < navigationHistory.count - 1 {
                navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
            }

            navigationHistory.append(url)
            currentHistoryIndex = navigationHistory.count - 1
        }

        loadDirectory(at: url)
    }

    func resetNavigation(to url: URL, selectingPath: String? = nil) {
        loadTask?.cancel()
        lastSelectedURL = nil
        selectedItems.removeAll()
        navigationHistory = [url]
        currentHistoryIndex = 0
        pendingSelectionPath = selectingPath.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        loadDirectory(at: url)
    }

    func resetState() {
        loadTask?.cancel()
        items = []
        selectedItems.removeAll()
        errorMessage = nil
        operationErrorMessage = nil
        requiresPermission = false
        isBlockedByDocumentsPrivacy = false
        pendingPermissionPath = nil
        isLoading = false
        navigationHistory = []
        currentHistoryIndex = -1
        lastSelectedURL = nil
        pendingSelectionPath = nil
    }

    func navigateBack() {
        guard canNavigateBack else { return }
        currentHistoryIndex -= 1

        if let url = currentDirectory {
            loadDirectory(at: url)
        }
    }

    func navigateForward() {
        guard canNavigateForward else { return }
        currentHistoryIndex += 1

        if let url = currentDirectory {
            loadDirectory(at: url)
        }
    }

    func navigateUp() {
        guard let current = currentDirectory else { return }
        let parent = current.deletingLastPathComponent()

        // Don't navigate if we're already at root
        guard parent.path != current.path else { return }

        navigateTo(url: parent)
    }

    func navigateToBreadcrumb(at index: Int) {
        guard let current = currentDirectory else { return }
        let components = current.pathComponents

        guard index < components.count else { return }

        let targetPath = components[0...index].joined(separator: "/")
        let targetURL = URL(fileURLWithPath: targetPath.hasPrefix("/") ? targetPath : "/" + targetPath)

        navigateTo(url: targetURL)
    }

    // MARK: - Directory Loading
    private func loadDirectory(at url: URL) {
        loadTask?.cancel()

        loadTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            requiresPermission = false
            isBlockedByDocumentsPrivacy = false
            pendingPermissionPath = nil

            // Small delay to debounce rapid navigation
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            await performLoad(at: url)

            isLoading = false
        }
    }

    private func performLoad(at url: URL) async {
        if permissionManager.isSystemManagedDocumentsPath(url.path) {
            let accessResult = await permissionManager.requestAccessToPath(url.path)

            guard accessResult == .granted else {
                if accessResult == .blockedByDocumentsPrivacy {
                    handleDocumentsPrivacyBlocked(for: url)
                } else {
                    handlePermissionDenied(for: url)
                }
                return
            }
        }

        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            errorMessage = "The path \"\(url.path)\" could not be opened."
            items = []
            return
        }

        guard permissionManager.validatePath(url.path) else {
            if permissionManager.isSystemManagedDocumentsPath(url.path) {
                handleDocumentsPrivacyBlocked(for: url)
            } else {
                handlePermissionDenied(for: url)
            }
            return
        }

        do {
            var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if !showHiddenFiles {
                options.insert(.skipsHiddenFiles)
            }

            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .contentTypeKey,
                    .fileSizeKey,
                    .creationDateKey,
                    .contentModificationDateKey
                ],
                options: options
            )

            var newItems: [FolderBrowserItem] = []

            for itemURL in urls {
                do {
                    let item = try FolderBrowserItem(url: itemURL)
                    newItems.append(item)
                } catch {
                    // Skip items that can't be read
                    print("Failed to create item for \(itemURL): \(error)")
                    continue
                }
            }

            items = sortItems(newItems)
            applyPendingSelectionIfNeeded()
            errorMessage = nil
            requiresPermission = false
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                if permissionManager.isSystemManagedDocumentsPath(url.path) {
                    handleDocumentsPrivacyBlocked(for: url)
                } else {
                    handlePermissionDenied(for: url)
                }
            } else {
                errorMessage = "Unable to read contents: \(error.localizedDescription)"
                items = []
            }
        }
    }

    private func handlePermissionDenied(for url: URL) {
        requiresPermission = true
        isBlockedByDocumentsPrivacy = false
        pendingPermissionPath = url.path
        errorMessage = "Permission is required to access this folder."
        items = []
    }

    private func handleDocumentsPrivacyBlocked(for url: URL) {
        requiresPermission = true
        isBlockedByDocumentsPrivacy = true
        pendingPermissionPath = url.path
        errorMessage = "Ventry can't access Documents."
        items = []
    }

    // MARK: - Sorting
    private func sortItems(_ items: [FolderBrowserItem]) -> [FolderBrowserItem] {
        items.sorted { lhs, rhs in
            // Directories always come first
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }

            switch sortOrder {
            case .nameAscending:
                return nameAscending(lhs, rhs)
            case .nameDescending:
                return !nameAscending(lhs, rhs)
            case .sizeAscending:
                if lhs.fileSize != rhs.fileSize {
                    return (lhs.fileSize ?? 0) < (rhs.fileSize ?? 0)
                }
                return nameAscending(lhs, rhs)
            case .sizeDescending:
                if lhs.fileSize != rhs.fileSize {
                    return (lhs.fileSize ?? 0) > (rhs.fileSize ?? 0)
                }
                return nameAscending(lhs, rhs)
            case .dateAscending:
                switch (lhs.modificationDate, rhs.modificationDate) {
                case let (left?, right?) where left != right:
                    return left < right
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return nameAscending(lhs, rhs)
                }
            case .dateDescending:
                switch (lhs.modificationDate, rhs.modificationDate) {
                case let (left?, right?) where left != right:
                    return left > right
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return nameAscending(lhs, rhs)
                }
            }
        }
    }

    private func nameAscending(_ lhs: FolderBrowserItem, _ rhs: FolderBrowserItem) -> Bool {
        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private func applyPendingSelectionIfNeeded() {
        guard let pendingSelectionPath else { return }
        defer { self.pendingSelectionPath = nil }

        guard let matchingItem = items.first(where: {
            $0.url.standardizedFileURL.path == pendingSelectionPath
        }) else {
            return
        }

        selectedItems = [matchingItem]
        lastSelectedURL = matchingItem.url.standardizedFileURL
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        items = sortItems(items)
    }

    // MARK: - Selection Management
    func selectItem(_ item: FolderBrowserItem) {
        selectedItems = [item]
        lastSelectedURL = item.url.standardizedFileURL
    }

    func toggleSelection(_ item: FolderBrowserItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
        lastSelectedURL = item.url.standardizedFileURL
    }

    func selectAll() {
        selectedItems = Set(items)
        lastSelectedURL = items.first?.url.standardizedFileURL
    }

    func deselectAll() {
        selectedItems.removeAll()
        lastSelectedURL = nil
    }

    func selectRange(to item: FolderBrowserItem, additive: Bool) {
        guard let anchorURL = lastSelectedURL else {
            selectItem(item)
            return
        }

        guard let anchorIndex = items.firstIndex(where: { $0.url.standardizedFileURL == anchorURL }),
              let targetIndex = items.firstIndex(where: { $0.url.standardizedFileURL == item.url.standardizedFileURL }) else {
            selectItem(item)
            return
        }

        let lower = min(anchorIndex, targetIndex)
        let upper = max(anchorIndex, targetIndex)
        let rangeItems = Set(items[lower...upper])

        if additive {
            selectedItems.formUnion(rangeItems)
        } else {
            selectedItems = rangeItems
        }
        lastSelectedURL = item.url.standardizedFileURL
    }

    /// Move selection by one or more rows in the current sorted `items` list.
    func moveSelection(by offset: Int) {
        guard !items.isEmpty, offset != 0 else { return }

        let selectedIndex: Int?
        if let lastSelectedURL {
            selectedIndex = items.firstIndex {
                $0.url.standardizedFileURL == lastSelectedURL
            }
        } else if let firstSelected = selectedItems.first {
            selectedIndex = items.firstIndex {
                $0.url.standardizedFileURL == firstSelected.url.standardizedFileURL
            }
        } else {
            selectedIndex = nil
        }

        let currentIndex = selectedIndex ?? (offset > 0 ? -1 : items.count)
        let nextIndex = min(max(currentIndex + offset, 0), items.count - 1)

        selectItem(items[nextIndex])
    }

    // MARK: - File Operations
    func revealInFinder(item: FolderBrowserItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func revealItemsInFinder(_ items: [FolderBrowserItem]) {
        let urls = items.map { $0.url.standardizedFileURL }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openFile(item: FolderBrowserItem) {
        if item.isDirectory {
            navigateTo(url: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func openSelectedItem() {
        guard canOpenSelection, let item = orderedSelectedItems.first else { return }
        openFile(item: item)
    }

    func copySelectedItems() {
        copySelectedItems(using: FolderBrowserClipboardController.shared)
    }

    func copySelectedItems(using clipboardController: FolderBrowserClipboardController) {
        let urls = orderedSelectedItems.map { $0.url.standardizedFileURL }
        guard !urls.isEmpty else { return }
        clipboardController.write(urls: urls, operation: .copy)
    }

    func cutSelectedItems() {
        cutSelectedItems(using: FolderBrowserClipboardController.shared)
    }

    func cutSelectedItems(using clipboardController: FolderBrowserClipboardController) {
        let urls = orderedSelectedItems.map { $0.url.standardizedFileURL }
        guard !urls.isEmpty else { return }
        clipboardController.write(urls: urls, operation: .cut)
    }

    func canPasteItems() -> Bool {
        canPasteItems(using: FolderBrowserClipboardController.shared)
    }

    func canPasteItems(using clipboardController: FolderBrowserClipboardController) -> Bool {
        currentDirectory != nil && clipboardController.hasPasteableFileURLs
    }

    func pasteItems() async throws -> Bool {
        try await pasteItems(using: FolderBrowserClipboardController.shared)
    }

    func pasteItems(using clipboardController: FolderBrowserClipboardController) async throws -> Bool {
        guard let destinationDirectory = currentDirectory else { return false }
        guard let request = clipboardController.currentPasteRequest() else { return false }

        let didMutate = try await importDroppedItems(
            request.urls,
            to: destinationDirectory,
            preferMove: request.preferMove
        )
        clipboardController.finalizePaste(request, didMutate: didMutate)
        return didMutate
    }

    func deleteItems(_ items: [FolderBrowserItem]) async throws {
        let validItems = items.map { $0.url.standardizedFileURL }
        guard !validItems.isEmpty else { return }

        let steps = validItems.map { FolderBrowserTrashStep(originalURL: $0) }
        let transaction = FolderBrowserMutationTransaction(
            actionName: "Move to Trash",
            steps: steps
        )

        try await performForwardTransaction(transaction, clearSelection: true)
    }

    func trashItems(at urls: [URL]) async throws {
        let validURLs = deduplicatedURLsPreservingOrder(urls.map { $0.standardizedFileURL })
        guard !validURLs.isEmpty else { return }

        let steps = validURLs.map { FolderBrowserTrashStep(originalURL: $0) }
        let transaction = FolderBrowserMutationTransaction(
            actionName: "Move to Trash",
            steps: steps
        )

        try await performForwardTransaction(transaction, clearSelection: true)
    }

    func finalizeExternalMove(for urls: [URL]) async throws {
        let uniqueURLs = deduplicatedURLsPreservingOrder(urls.map { $0.standardizedFileURL })
        guard !uniqueURLs.isEmpty else { return }

        let existingURLs = uniqueURLs.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existingURLs.isEmpty else {
            await refreshAfterMutation(clearSelection: true)
            return
        }

        let steps = existingURLs.map { FolderBrowserTrashStep(originalURL: $0) }
        let transaction = FolderBrowserMutationTransaction(
            actionName: "Move to Trash",
            steps: steps
        )

        try await performForwardTransaction(transaction, clearSelection: true)
    }

    func duplicateItems(_ items: [FolderBrowserItem]) async throws {
        guard !items.isEmpty else { return }

        var reservedPaths = Set<String>()
        var steps: [FolderBrowserMutationStep] = []
        steps.reserveCapacity(items.count)

        for item in items {
            let sourceURL = item.url.standardizedFileURL
            let parentURL = sourceURL.deletingLastPathComponent().standardizedFileURL
            let destinationURL = uniqueDestinationURL(
                for: sourceURL,
                in: parentURL,
                reservedPaths: reservedPaths
            )
            reservedPaths.insert(destinationURL.path)
            steps.append(FolderBrowserCopyStep(sourceURL: sourceURL, destinationURL: destinationURL))
        }

        let transaction = FolderBrowserMutationTransaction(
            actionName: "Duplicate",
            steps: steps
        )
        try await performForwardTransaction(transaction, clearSelection: false)
    }

    func renameItem(_ item: FolderBrowserItem, to newName: String) async throws {
        let sourceURL = item.url.standardizedFileURL
        let newURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent(newName)
            .standardizedFileURL

        guard !fileManager.fileExists(atPath: newURL.path) else {
            throw NSError(domain: "FolderBrowser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "An item with the name '\(newName)' already exists."
            ])
        }

        let transaction = FolderBrowserMutationTransaction(
            actionName: "Rename",
            steps: [FolderBrowserMoveStep(sourceURL: sourceURL, destinationURL: newURL)]
        )
        try await performForwardTransaction(transaction, clearSelection: false)
    }

    func importDroppedItems(
        _ droppedURLs: [URL],
        to destinationDirectory: URL,
        preferMove: Bool
    ) async throws -> Bool {
        guard !droppedURLs.isEmpty else { return false }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NSError(domain: "FolderBrowser", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Drop destination does not exist."
            ])
        }

        let uniqueURLs = deduplicatedURLsPreservingOrder(droppedURLs.map { $0.standardizedFileURL })
        let destinationRoot = destinationDirectory.standardizedFileURL
        var reservedPaths = Set<String>()
        var steps: [FolderBrowserMutationStep] = []
        steps.reserveCapacity(uniqueURLs.count)

        for sourceURL in uniqueURLs {
            if let step = try buildDropMutationStep(
                sourceURL,
                to: destinationRoot,
                reservedPaths: &reservedPaths,
                preferMove: preferMove
            ) {
                steps.append(step)
            }
        }

        guard !steps.isEmpty else { return false }
        let transaction = FolderBrowserMutationTransaction(
            actionName: preferMove ? "Move" : "Copy",
            steps: steps
        )
        try await performForwardTransaction(transaction, clearSelection: false)
        return true
    }

    private func performForwardTransaction(
        _ transaction: FolderBrowserMutationTransaction,
        clearSelection: Bool
    ) async throws {
        guard !transaction.isEmpty else { return }
        try transaction.applyForward(fileManager: fileManager)
        registerUndo(for: transaction)
        await refreshAfterMutation(clearSelection: clearSelection)
    }

    private func executeUndo(_ transaction: FolderBrowserMutationTransaction) async {
        do {
            try transaction.applyUndo(fileManager: fileManager)
            registerRedo(for: transaction)
            await refreshAfterMutation(clearSelection: true)
        } catch {
            operationErrorMessage = "Undo failed: \(error.localizedDescription)"
        }
    }

    private func executeRedo(_ transaction: FolderBrowserMutationTransaction) async {
        do {
            try transaction.applyRedo(fileManager: fileManager)
            registerUndo(for: transaction)
            await refreshAfterMutation(clearSelection: true)
        } catch {
            operationErrorMessage = "Redo failed: \(error.localizedDescription)"
        }
    }

    private func registerUndo(for transaction: FolderBrowserMutationTransaction) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                await target.executeUndo(transaction)
            }
        }
        undoManager.setActionName(transaction.actionName)
    }

    private func registerRedo(for transaction: FolderBrowserMutationTransaction) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                await target.executeRedo(transaction)
            }
        }
        undoManager.setActionName(transaction.actionName)
    }

    private func refreshAfterMutation(clearSelection: Bool) async {
        if let current = currentDirectory {
            await performLoad(at: current)
        }

        if clearSelection {
            selectedItems.removeAll()
        }
    }

    func refresh() {
        if let current = currentDirectory {
            loadDirectory(at: current)
        }
    }

    func requestPermissionAndRefresh() {
        guard let pendingPath = pendingPermissionPath ?? currentDirectory?.path else {
            refresh()
            return
        }

        Task {
            let result = await permissionManager.requestAccessToPath(pendingPath)

            await MainActor.run {
                switch result {
                case .granted:
                    self.refresh()
                case .blockedByDocumentsPrivacy:
                    self.handleDocumentsPrivacyBlocked(for: URL(fileURLWithPath: pendingPath))
                case .denied:
                    self.handlePermissionDenied(for: URL(fileURLWithPath: pendingPath))
                }
            }
        }
    }

    func openPrivacySettings() {
        permissionManager.openDocumentsPrivacySettings()
    }

    func showInfo(for items: [FolderBrowserItem]) {
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
                if let error {
                    print("AppleScript error: \(error)")
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }

    // MARK: - Breadcrumb Management
    var breadcrumbs: [String] {
        guard let current = currentDirectory else { return [] }
        return current.pathComponents.filter { $0 != "/" }
    }

    private func buildDropMutationStep(
        _ sourceURL: URL,
        to destinationDirectory: URL,
        reservedPaths: inout Set<String>,
        preferMove: Bool
    ) throws -> FolderBrowserMutationStep? {
        let source = sourceURL.standardizedFileURL
        let destinationRoot = destinationDirectory.standardizedFileURL

        // Reject dropping a folder into itself or one of its descendants.
        if isDirectory(at: source),
           (source == destinationRoot || destinationRoot.path.hasPrefix(source.path + "/")) {
            throw NSError(domain: "FolderBrowser", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Cannot place a folder inside itself."
            ])
        }

        let sourceParent = source.deletingLastPathComponent().standardizedFileURL
        let sameParent = sourceParent == destinationRoot

        // Same-directory move is a no-op.
        if preferMove && sameParent {
            return nil
        }

        let destinationURL = uniqueDestinationURL(
            for: source,
            in: destinationRoot,
            reservedPaths: reservedPaths
        )
        reservedPaths.insert(destinationURL.path)

        if preferMove {
            return FolderBrowserMoveStep(sourceURL: source, destinationURL: destinationURL)
        } else {
            return FolderBrowserCopyStep(sourceURL: source, destinationURL: destinationURL)
        }
    }

    private func deduplicatedURLsPreservingOrder(_ urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()
        var results: [URL] = []
        results.reserveCapacity(urls.count)

        for url in urls {
            let standardized = url.standardizedFileURL
            if seenPaths.insert(standardized.path).inserted {
                results.append(standardized)
            }
        }
        return results
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    private func uniqueDestinationURL(
        for sourceURL: URL,
        in destinationDirectory: URL,
        reservedPaths: Set<String> = []
    ) -> URL {
        let preferred = destinationDirectory
            .appendingPathComponent(sourceURL.lastPathComponent)
            .standardizedFileURL
        guard !fileManager.fileExists(atPath: preferred.path),
              !reservedPaths.contains(preferred.path) else {
            return resolveUniqueDestination(
                baseURL: preferred,
                sourceURL: sourceURL,
                destinationDirectory: destinationDirectory,
                reservedPaths: reservedPaths
            )
        }
        return preferred
    }

    private func resolveUniqueDestination(
        baseURL: URL,
        sourceURL: URL,
        destinationDirectory: URL,
        reservedPaths: Set<String>
    ) -> URL {
        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var counter = 1
        var candidate = baseURL

        repeat {
            let newName = ext.isEmpty
                ? "\(baseName) \(counter)"
                : "\(baseName) \(counter).\(ext)"
            candidate = destinationDirectory
                .appendingPathComponent(newName)
                .standardizedFileURL
            counter += 1
        } while fileManager.fileExists(atPath: candidate.path) || reservedPaths.contains(candidate.path)

        return candidate
    }

    // MARK: - Cleanup
    deinit {
        loadTask?.cancel()
    }
}

// MARK: - Sort Order
enum SortOrder: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case sizeAscending = "Size (Smallest)"
    case sizeDescending = "Size (Largest)"
    case dateAscending = "Date (Oldest)"
    case dateDescending = "Date (Newest)"

    var systemImage: String {
        switch self {
        case .nameAscending:
            return "textformat.abc"
        case .nameDescending:
            return "textformat.abc"
        case .sizeAscending:
            return "arrow.up.circle"
        case .sizeDescending:
            return "arrow.down.circle"
        case .dateAscending:
            return "calendar.badge.clock"
        case .dateDescending:
            return "calendar.badge.clock"
        }
    }
}
