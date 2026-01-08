import Foundation
import SwiftUI
import Combine

@MainActor
class FolderBrowserViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [FolderBrowserItem] = []
    @Published var selectedItems: Set<FolderBrowserItem> = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var sortOrder: SortOrder = .nameAscending
    @Published var showHiddenFiles = false

    // Navigation state
    @Published var navigationHistory: [URL] = []
    @Published var currentHistoryIndex: Int = -1

    var currentDirectory: URL? {
        guard currentHistoryIndex >= 0 && currentHistoryIndex < navigationHistory.count else {
            return nil
        }
        return navigationHistory[currentHistoryIndex]
    }

    var canNavigateBack: Bool {
        currentHistoryIndex > 0
    }

    var canNavigateForward: Bool {
        currentHistoryIndex < navigationHistory.count - 1
    }

    // MARK: - Private Properties
    private var loadTask: Task<Void, Never>?
    private let fileManager = FileManager.default

    // MARK: - Initialization
    init() {}

    // MARK: - Navigation Methods
    func navigateTo(url: URL, addToHistory: Bool = true) {
        loadTask?.cancel()

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
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            errorMessage = "The path \"\(url.path)\" could not be opened."
            items = []
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
            errorMessage = nil
        } catch {
            errorMessage = "Unable to read contents: \(error.localizedDescription)"
            items = []
        }
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
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            case .nameDescending:
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedDescending
            case .sizeAscending:
                return (lhs.fileSize ?? 0) < (rhs.fileSize ?? 0)
            case .sizeDescending:
                return (lhs.fileSize ?? 0) > (rhs.fileSize ?? 0)
            case .dateAscending:
                guard let lhsDate = lhs.modificationDate, let rhsDate = rhs.modificationDate else {
                    return false
                }
                return lhsDate < rhsDate
            case .dateDescending:
                guard let lhsDate = lhs.modificationDate, let rhsDate = rhs.modificationDate else {
                    return false
                }
                return lhsDate > rhsDate
            }
        }
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        items = sortItems(items)
    }

    // MARK: - Selection Management
    func selectItem(_ item: FolderBrowserItem) {
        selectedItems = [item]
    }

    func toggleSelection(_ item: FolderBrowserItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }

    func selectAll() {
        selectedItems = Set(items)
    }

    func deselectAll() {
        selectedItems.removeAll()
    }

    // MARK: - File Operations
    func revealInFinder(item: FolderBrowserItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func openFile(item: FolderBrowserItem) {
        if item.isDirectory {
            navigateTo(url: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func deleteItems(_ items: [FolderBrowserItem]) async throws {
        for item in items {
            try fileManager.trashItem(at: item.url, resultingItemURL: nil)
        }

        // Refresh the current directory
        if let current = currentDirectory {
            await performLoad(at: current)
        }

        selectedItems.removeAll()
    }

    func renameItem(_ item: FolderBrowserItem, to newName: String) async throws {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)

        guard !fileManager.fileExists(atPath: newURL.path) else {
            throw NSError(domain: "FolderBrowser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "An item with the name '\(newName)' already exists."
            ])
        }

        try fileManager.moveItem(at: item.url, to: newURL)

        // Refresh the current directory
        if let current = currentDirectory {
            await performLoad(at: current)
        }
    }

    func refresh() {
        if let current = currentDirectory {
            loadDirectory(at: current)
        }
    }

    // MARK: - Breadcrumb Management
    var breadcrumbs: [String] {
        guard let current = currentDirectory else { return [] }
        return current.pathComponents.filter { $0 != "/" }
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
