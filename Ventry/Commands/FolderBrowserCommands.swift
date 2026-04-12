import SwiftUI
import AppKit

@MainActor
final class FolderBrowserCommandHandler {
    private let canCopySelectionProvider: () -> Bool
    private let canCutSelectionProvider: () -> Bool
    private let canPasteProvider: () -> Bool
    private let canDuplicateSelectionProvider: () -> Bool
    private let canTrashSelectionProvider: () -> Bool
    private let canRenameSelectionProvider: () -> Bool
    private let canOpenSelectionProvider: () -> Bool
    private let canQuickLookSelectionProvider: () -> Bool
    private let canShowInfoProvider: () -> Bool
    private let canRevealSelectionProvider: () -> Bool
    private let canNavigateBackProvider: () -> Bool
    private let canNavigateForwardProvider: () -> Bool
    private let canNavigateUpProvider: () -> Bool
    private let canSelectAllProvider: () -> Bool
    private let canDeselectAllProvider: () -> Bool
    private let currentViewModeProvider: () -> BrowserViewMode
    private let copySelectionAction: () -> Void
    private let cutSelectionAction: () -> Void
    private let pasteAction: () -> Void
    private let duplicateSelectionAction: () -> Void
    private let trashSelectionAction: () -> Void
    private let renameSelectionAction: () -> Void
    private let openSelectionAction: () -> Void
    private let quickLookSelectionAction: () -> Void
    private let showInfoAction: () -> Void
    private let revealSelectionAction: () -> Void
    private let navigateBackAction: () -> Void
    private let navigateForwardAction: () -> Void
    private let navigateUpAction: () -> Void
    private let selectAllAction: () -> Void
    private let deselectAllAction: () -> Void
    private let setViewModeAction: (BrowserViewMode) -> Void

    init(
        canCopySelection: @escaping () -> Bool,
        canCutSelection: @escaping () -> Bool,
        canPaste: @escaping () -> Bool,
        canDuplicateSelection: @escaping () -> Bool,
        canTrashSelection: @escaping () -> Bool,
        canRenameSelection: @escaping () -> Bool,
        canOpenSelection: @escaping () -> Bool,
        canQuickLookSelection: @escaping () -> Bool,
        canShowInfo: @escaping () -> Bool,
        canRevealSelection: @escaping () -> Bool,
        canNavigateBack: @escaping () -> Bool,
        canNavigateForward: @escaping () -> Bool,
        canNavigateUp: @escaping () -> Bool,
        canSelectAll: @escaping () -> Bool,
        canDeselectAll: @escaping () -> Bool,
        currentViewMode: @escaping () -> BrowserViewMode,
        copySelection: @escaping () -> Void,
        cutSelection: @escaping () -> Void,
        paste: @escaping () -> Void,
        duplicateSelection: @escaping () -> Void,
        trashSelection: @escaping () -> Void,
        renameSelection: @escaping () -> Void,
        openSelection: @escaping () -> Void,
        quickLookSelection: @escaping () -> Void,
        showInfo: @escaping () -> Void,
        revealSelection: @escaping () -> Void,
        navigateBack: @escaping () -> Void,
        navigateForward: @escaping () -> Void,
        navigateUp: @escaping () -> Void,
        selectAll: @escaping () -> Void,
        deselectAll: @escaping () -> Void,
        setViewMode: @escaping (BrowserViewMode) -> Void
    ) {
        self.canCopySelectionProvider = canCopySelection
        self.canCutSelectionProvider = canCutSelection
        self.canPasteProvider = canPaste
        self.canDuplicateSelectionProvider = canDuplicateSelection
        self.canTrashSelectionProvider = canTrashSelection
        self.canRenameSelectionProvider = canRenameSelection
        self.canOpenSelectionProvider = canOpenSelection
        self.canQuickLookSelectionProvider = canQuickLookSelection
        self.canShowInfoProvider = canShowInfo
        self.canRevealSelectionProvider = canRevealSelection
        self.canNavigateBackProvider = canNavigateBack
        self.canNavigateForwardProvider = canNavigateForward
        self.canNavigateUpProvider = canNavigateUp
        self.canSelectAllProvider = canSelectAll
        self.canDeselectAllProvider = canDeselectAll
        self.currentViewModeProvider = currentViewMode
        self.copySelectionAction = copySelection
        self.cutSelectionAction = cutSelection
        self.pasteAction = paste
        self.duplicateSelectionAction = duplicateSelection
        self.trashSelectionAction = trashSelection
        self.renameSelectionAction = renameSelection
        self.openSelectionAction = openSelection
        self.quickLookSelectionAction = quickLookSelection
        self.showInfoAction = showInfo
        self.revealSelectionAction = revealSelection
        self.navigateBackAction = navigateBack
        self.navigateForwardAction = navigateForward
        self.navigateUpAction = navigateUp
        self.selectAllAction = selectAll
        self.deselectAllAction = deselectAll
        self.setViewModeAction = setViewMode
    }

    var canCopySelection: Bool { canCopySelectionProvider() }
    var canCutSelection: Bool { canCutSelectionProvider() }
    var canPaste: Bool { canPasteProvider() }
    var canDuplicateSelection: Bool { canDuplicateSelectionProvider() }
    var canTrashSelection: Bool { canTrashSelectionProvider() }
    var canRenameSelection: Bool { canRenameSelectionProvider() }
    var canOpenSelection: Bool { canOpenSelectionProvider() }
    var canQuickLookSelection: Bool { canQuickLookSelectionProvider() }
    var canShowInfo: Bool { canShowInfoProvider() }
    var canRevealSelection: Bool { canRevealSelectionProvider() }
    var canNavigateBack: Bool { canNavigateBackProvider() }
    var canNavigateForward: Bool { canNavigateForwardProvider() }
    var canNavigateUp: Bool { canNavigateUpProvider() }
    var canSelectAll: Bool { canSelectAllProvider() }
    var canDeselectAll: Bool { canDeselectAllProvider() }
    var currentViewMode: BrowserViewMode { currentViewModeProvider() }

    func copySelection() { copySelectionAction() }
    func cutSelection() { cutSelectionAction() }
    func paste() { pasteAction() }
    func duplicateSelection() { duplicateSelectionAction() }
    func trashSelection() { trashSelectionAction() }
    func renameSelection() { renameSelectionAction() }
    func openSelection() { openSelectionAction() }
    func quickLookSelection() { quickLookSelectionAction() }
    func showInfo() { showInfoAction() }
    func revealSelection() { revealSelectionAction() }
    func navigateBack() { navigateBackAction() }
    func navigateForward() { navigateForwardAction() }
    func navigateUp() { navigateUpAction() }
    func selectAll() { selectAllAction() }
    func deselectAll() { deselectAllAction() }
    func setViewMode(_ mode: BrowserViewMode) { setViewModeAction(mode) }
}

private struct FolderBrowserCommandHandlerKey: FocusedValueKey {
    typealias Value = FolderBrowserCommandHandler
}

extension FocusedValues {
    var folderBrowserCommandHandler: FolderBrowserCommandHandler? {
        get { self[FolderBrowserCommandHandlerKey.self] }
        set { self[FolderBrowserCommandHandlerKey.self] = newValue }
    }
}

@MainActor
final class BrowserTabCommandHandler {
    private let canCreateNewTabProvider: () -> Bool
    private let canCloseActiveTabProvider: () -> Bool
    private let canSelectPreviousTabProvider: () -> Bool
    private let canSelectNextTabProvider: () -> Bool
    private let createNewTabAction: () -> Void
    private let closeActiveTabAction: () -> Void
    private let selectPreviousTabAction: () -> Void
    private let selectNextTabAction: () -> Void

    init(
        canCreateNewTab: @escaping () -> Bool,
        canCloseActiveTab: @escaping () -> Bool,
        canSelectPreviousTab: @escaping () -> Bool,
        canSelectNextTab: @escaping () -> Bool,
        createNewTab: @escaping () -> Void,
        closeActiveTab: @escaping () -> Void,
        selectPreviousTab: @escaping () -> Void,
        selectNextTab: @escaping () -> Void
    ) {
        self.canCreateNewTabProvider = canCreateNewTab
        self.canCloseActiveTabProvider = canCloseActiveTab
        self.canSelectPreviousTabProvider = canSelectPreviousTab
        self.canSelectNextTabProvider = canSelectNextTab
        self.createNewTabAction = createNewTab
        self.closeActiveTabAction = closeActiveTab
        self.selectPreviousTabAction = selectPreviousTab
        self.selectNextTabAction = selectNextTab
    }

    var canCreateNewTab: Bool { canCreateNewTabProvider() }
    var canCloseActiveTab: Bool { canCloseActiveTabProvider() }
    var canSelectPreviousTab: Bool { canSelectPreviousTabProvider() }
    var canSelectNextTab: Bool { canSelectNextTabProvider() }

    func createNewTab() { createNewTabAction() }
    func closeActiveTab() { closeActiveTabAction() }
    func selectPreviousTab() { selectPreviousTabAction() }
    func selectNextTab() { selectNextTabAction() }
}

private struct BrowserTabCommandHandlerKey: FocusedValueKey {
    typealias Value = BrowserTabCommandHandler
}

extension FocusedValues {
    var browserTabCommandHandler: BrowserTabCommandHandler? {
        get { self[BrowserTabCommandHandlerKey.self] }
        set { self[BrowserTabCommandHandlerKey.self] = newValue }
    }
}

enum FolderBrowserCommandSupport {
    static var isTextInputActive: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    static func canPerformResponderAction(_ selector: Selector) -> Bool {
        NSApp.target(forAction: selector, to: nil, from: nil) != nil
    }

    static func performResponderAction(_ selector: Selector) {
        NSApp.sendAction(selector, to: nil, from: nil)
    }
}

struct FolderBrowserCommands: Commands {
    @FocusedValue(\.folderBrowserCommandHandler) private var folderBrowserCommandHandler
    @FocusedValue(\.browserTabCommandHandler) private var browserTabCommandHandler

    private var activeBrowserCommandHandler: FolderBrowserCommandHandler? {
        guard !FolderBrowserCommandSupport.isTextInputActive else { return nil }
        return folderBrowserCommandHandler
    }

    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                performPasteboardAction(
                    browserAvailability: { $0.canCutSelection },
                    browserAction: { $0.cutSelection() },
                    responderSelector: #selector(NSText.cut(_:))
                )
            }
            .keyboardShortcut("x", modifiers: [.command])
            .disabled(!canPerformPasteboardAction(
                browserAvailability: { $0.canCutSelection },
                responderSelector: #selector(NSText.cut(_:))
            ))

            Button("Copy") {
                performPasteboardAction(
                    browserAvailability: { $0.canCopySelection },
                    browserAction: { $0.copySelection() },
                    responderSelector: #selector(NSText.copy(_:))
                )
            }
            .keyboardShortcut("c", modifiers: [.command])
            .disabled(!canPerformPasteboardAction(
                browserAvailability: { $0.canCopySelection },
                responderSelector: #selector(NSText.copy(_:))
            ))

            Button("Paste") {
                performPasteboardAction(
                    browserAvailability: { $0.canPaste },
                    browserAction: { $0.paste() },
                    responderSelector: #selector(NSText.paste(_:))
                )
            }
            .keyboardShortcut("v", modifiers: [.command])
            .disabled(!canPerformPasteboardAction(
                browserAvailability: { $0.canPaste },
                responderSelector: #selector(NSText.paste(_:))
            ))

            Divider()

            Button("Select All") {
                performPasteboardAction(
                    browserAvailability: { $0.canSelectAll },
                    browserAction: { $0.selectAll() },
                    responderSelector: #selector(NSText.selectAll(_:))
                )
            }
            .keyboardShortcut("a", modifiers: [.command])
            .disabled(!canPerformPasteboardAction(
                browserAvailability: { $0.canSelectAll },
                responderSelector: #selector(NSText.selectAll(_:))
            ))

            Button("Deselect All") {
                activeBrowserCommandHandler?.deselectAll()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(activeBrowserCommandHandler?.canDeselectAll != true)
        }

        CommandGroup(after: .newItem) {
            Button("New Tab") {
                browserTabCommandHandler?.createNewTab()
            }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(browserTabCommandHandler?.canCreateNewTab != true)
        }

        CommandMenu("Browser") {
            Button("Quick Look") {
                activeBrowserCommandHandler?.quickLookSelection()
            }
            .disabled(activeBrowserCommandHandler?.canQuickLookSelection != true)

            Button("Open") {
                activeBrowserCommandHandler?.openSelection()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canOpenSelection != true)

            Button("Rename") {
                activeBrowserCommandHandler?.renameSelection()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canRenameSelection != true)

            Button("Duplicate") {
                activeBrowserCommandHandler?.duplicateSelection()
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canDuplicateSelection != true)

            Button("Move to Trash") {
                activeBrowserCommandHandler?.trashSelection()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canTrashSelection != true)

            Divider()

            Button("Get Info") {
                activeBrowserCommandHandler?.showInfo()
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canShowInfo != true)

            Button("Reveal in Finder") {
                activeBrowserCommandHandler?.revealSelection()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(activeBrowserCommandHandler?.canRevealSelection != true)

            Divider()

            Button("Back") {
                activeBrowserCommandHandler?.navigateBack()
            }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canNavigateBack != true)

            Button("Forward") {
                activeBrowserCommandHandler?.navigateForward()
            }
            .keyboardShortcut("]", modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canNavigateForward != true)

            Button("Up") {
                activeBrowserCommandHandler?.navigateUp()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])
            .disabled(activeBrowserCommandHandler?.canNavigateUp != true)

            Divider()

            viewModeButton(title: "Grid View", mode: .grid, shortcut: "1")
            viewModeButton(title: "List View", mode: .list, shortcut: "2")
            viewModeButton(title: "Column View", mode: .column, shortcut: "3")
        }

        CommandMenu("Tabs") {
            Button("New Tab") {
                browserTabCommandHandler?.createNewTab()
            }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(browserTabCommandHandler?.canCreateNewTab != true)

            Button("Close Tab") {
                browserTabCommandHandler?.closeActiveTab()
            }
            .disabled(browserTabCommandHandler?.canCloseActiveTab != true)

            Divider()

            Button("Previous Tab") {
                browserTabCommandHandler?.selectPreviousTab()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(browserTabCommandHandler?.canSelectPreviousTab != true)

            Button("Next Tab") {
                browserTabCommandHandler?.selectNextTab()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(browserTabCommandHandler?.canSelectNextTab != true)
        }
    }

    private func canPerformPasteboardAction(
        browserAvailability: (FolderBrowserCommandHandler) -> Bool,
        responderSelector: Selector
    ) -> Bool {
        if let activeBrowserCommandHandler {
            return browserAvailability(activeBrowserCommandHandler)
        }

        return FolderBrowserCommandSupport.canPerformResponderAction(responderSelector)
    }

    private func performPasteboardAction(
        browserAvailability: (FolderBrowserCommandHandler) -> Bool,
        browserAction: (FolderBrowserCommandHandler) -> Void,
        responderSelector: Selector
    ) {
        if let activeBrowserCommandHandler,
           browserAvailability(activeBrowserCommandHandler) {
            browserAction(activeBrowserCommandHandler)
            return
        }

        FolderBrowserCommandSupport.performResponderAction(responderSelector)
    }

    @ViewBuilder
    private func viewModeButton(title: String, mode: BrowserViewMode, shortcut: KeyEquivalent) -> some View {
        Button(action: {
            activeBrowserCommandHandler?.setViewMode(mode)
        }) {
            HStack {
                Text(title)
                if activeBrowserCommandHandler?.currentViewMode == mode {
                    Image(systemName: "checkmark")
                }
            }
        }
        .keyboardShortcut(shortcut, modifiers: [.command])
        .disabled(activeBrowserCommandHandler == nil)
    }
}
