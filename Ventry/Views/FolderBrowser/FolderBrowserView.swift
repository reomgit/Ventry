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
                    onItemDoubleClick: handleItemDoubleClick,
                    onItemClick: handleItemClick
                )
            case .list:
                FolderBrowserListView(
                    items: viewModel.items,
                    selectedItems: $viewModel.selectedItems,
                    onItemDoubleClick: handleItemDoubleClick,
                    onItemClick: handleItemClick
                )
            case .column:
                FolderBrowserColumnView(
                    items: viewModel.items,
                    selectedItems: $viewModel.selectedItems,
                    onItemDoubleClick: handleItemDoubleClick,
                    onItemClick: handleItemClick
                )
            }
        }
        .quickLookPreview(items: viewModel.items, selectedItems: $viewModel.selectedItems)
        .contextMenu(forSelectionType: FolderBrowserItem.self) { items in
            contextMenuContent(for: Array(items))
        }
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
    }

    @ViewBuilder
    private func contextMenuContent(for items: [FolderBrowserItem]) -> some View {
        if items.isEmpty {
            EmptyView()
        } else {
            if items.count == 1, let item = items.first {
                Button("Open") {
                    viewModel.openFile(item: item)
                }

                if !item.isDirectory {
                    Button("Quick Look") {
                        viewModel.selectItem(item)
                        // Trigger Quick Look via spacebar simulation
                    }
                }

                Divider()
            }

            Button("Get Info") {
                showInfo(for: items)
            }

            Divider()

            if items.count == 1 {
                Button("Rename...") {
                    startRename(items[0])
                }
            }

            Button("Copy") {
                copyItems(items)
            }

            Button("Duplicate") {
                duplicateItems(items)
            }

            Divider()

            Button("Move to Trash") {
                itemsToDelete = items
                showingDeleteAlert = true
            }

            Divider()

            Button("Reveal in Finder") {
                items.forEach { viewModel.revealInFinder(item: $0) }
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
    private func handleItemClick(_ item: FolderBrowserItem, isCommandKey: Bool) {
        if isCommandKey {
            viewModel.toggleSelection(item)
        } else {
            viewModel.selectItem(item)
        }
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
        // Open Finder's Get Info window
        items.forEach { item in
            NSWorkspace.shared.open(item.url)
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
