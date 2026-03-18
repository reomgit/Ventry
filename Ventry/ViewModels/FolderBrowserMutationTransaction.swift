import Foundation

final class FolderBrowserMutationTransaction {
    let actionName: String
    private let steps: [FolderBrowserMutationStep]

    var isEmpty: Bool {
        steps.isEmpty
    }

    init(actionName: String, steps: [FolderBrowserMutationStep]) {
        self.actionName = actionName
        self.steps = steps
    }

    func applyForward(fileManager: FileManager) throws {
        try apply(direction: .forward, fileManager: fileManager)
    }

    func applyUndo(fileManager: FileManager) throws {
        try apply(direction: .undo, fileManager: fileManager)
    }

    func applyRedo(fileManager: FileManager) throws {
        try apply(direction: .redo, fileManager: fileManager)
    }

    private func apply(direction: FolderBrowserMutationDirection, fileManager: FileManager) throws {
        let orderedSteps = direction.orderedSteps(from: steps)
        var completedSteps: [FolderBrowserMutationStep] = []
        completedSteps.reserveCapacity(orderedSteps.count)

        do {
            for step in orderedSteps {
                try direction.apply(step: step, fileManager: fileManager)
                direction.syncStarredItems(for: step)
                completedSteps.append(step)
            }
        } catch {
            for step in completedSteps.reversed() {
                try? direction.rollback(step: step, fileManager: fileManager)
                direction.rollbackStarredItems(for: step)
            }
            throw error
        }
    }
}

protocol FolderBrowserMutationStep: AnyObject {
    func applyForward(fileManager: FileManager) throws
    func applyUndo(fileManager: FileManager) throws
    func applyRedo(fileManager: FileManager) throws
    func syncStarredItemsAfterForward()
    func syncStarredItemsAfterUndo()
    func syncStarredItemsAfterRedo()
}

extension FolderBrowserMutationStep {
    func syncStarredItemsAfterForward() {}
    func syncStarredItemsAfterUndo() {}
    func syncStarredItemsAfterRedo() {}
}

final class FolderBrowserMoveStep: FolderBrowserMutationStep {
    private let sourceURL: URL
    private let destinationURL: URL

    init(sourceURL: URL, destinationURL: URL) {
        self.sourceURL = sourceURL.standardizedFileURL
        self.destinationURL = destinationURL.standardizedFileURL
    }

    func applyForward(fileManager: FileManager) throws {
        try moveItem(
            from: sourceURL,
            to: destinationURL,
            fileManager: fileManager
        )
    }

    func applyUndo(fileManager: FileManager) throws {
        try moveItem(
            from: destinationURL,
            to: sourceURL,
            fileManager: fileManager
        )
    }

    func applyRedo(fileManager: FileManager) throws {
        try moveItem(
            from: sourceURL,
            to: destinationURL,
            fileManager: fileManager
        )
    }

    func syncStarredItemsAfterForward() {
        do {
            try StarredItemsStore.shared.replacePathPrefix(from: sourceURL, to: destinationURL)
        } catch {
            print("Failed to update starred items after move: \(error)")
        }
    }

    func syncStarredItemsAfterUndo() {
        do {
            try StarredItemsStore.shared.replacePathPrefix(from: destinationURL, to: sourceURL)
        } catch {
            print("Failed to update starred items after undoing move: \(error)")
        }
    }

    func syncStarredItemsAfterRedo() {
        syncStarredItemsAfterForward()
    }
}

final class FolderBrowserTrashStep: FolderBrowserMutationStep {
    private let originalURL: URL
    private var trashedURL: URL?
    private var removedStarredItems: [RemovedStarredItemRecord] = []

    init(originalURL: URL) {
        self.originalURL = originalURL.standardizedFileURL
    }

    func applyForward(fileManager: FileManager) throws {
        trashedURL = try trashItem(at: originalURL, fileManager: fileManager)
    }

    func applyUndo(fileManager: FileManager) throws {
        guard let trashedURL else {
            throw folderBrowserError(
                "Undo failed because the trash location for '\(originalURL.lastPathComponent)' was not recorded."
            )
        }
        try restoreFromTrash(
            trashedURL: trashedURL,
            to: originalURL,
            fileManager: fileManager
        )
    }

    func applyRedo(fileManager: FileManager) throws {
        trashedURL = try trashItem(at: originalURL, fileManager: fileManager)
    }

    func syncStarredItemsAfterForward() {
        do {
            removedStarredItems = try StarredItemsStore.shared.removeItems(atOrInside: originalURL)
        } catch {
            print("Failed to remove starred items after trashing item: \(error)")
        }
    }

    func syncStarredItemsAfterUndo() {
        do {
            try StarredItemsStore.shared.restore(removedStarredItems)
        } catch {
            print("Failed to restore starred items after undoing trash: \(error)")
        }
    }

    func syncStarredItemsAfterRedo() {
        syncStarredItemsAfterForward()
    }
}

final class FolderBrowserCopyStep: FolderBrowserMutationStep {
    private let sourceURL: URL
    private let destinationURL: URL
    private var trashedDestinationURL: URL?

    init(sourceURL: URL, destinationURL: URL) {
        self.sourceURL = sourceURL.standardizedFileURL
        self.destinationURL = destinationURL.standardizedFileURL
    }

    func applyForward(fileManager: FileManager) throws {
        try copyItem(
            from: sourceURL,
            to: destinationURL,
            fileManager: fileManager
        )
    }

    func applyUndo(fileManager: FileManager) throws {
        trashedDestinationURL = try trashItem(at: destinationURL, fileManager: fileManager)
    }

    func applyRedo(fileManager: FileManager) throws {
        if let trashedDestinationURL,
           fileManager.fileExists(atPath: trashedDestinationURL.path) {
            try restoreFromTrash(
                trashedURL: trashedDestinationURL,
                to: destinationURL,
                fileManager: fileManager
            )
            return
        }

        try copyItem(
            from: sourceURL,
            to: destinationURL,
            fileManager: fileManager
        )
    }
}

private enum FolderBrowserMutationDirection {
    case forward
    case undo
    case redo

    func orderedSteps(from steps: [FolderBrowserMutationStep]) -> [FolderBrowserMutationStep] {
        switch self {
        case .undo:
            return steps.reversed()
        case .forward, .redo:
            return steps
        }
    }

    func apply(step: FolderBrowserMutationStep, fileManager: FileManager) throws {
        switch self {
        case .forward:
            try step.applyForward(fileManager: fileManager)
        case .undo:
            try step.applyUndo(fileManager: fileManager)
        case .redo:
            try step.applyRedo(fileManager: fileManager)
        }
    }

    func rollback(step: FolderBrowserMutationStep, fileManager: FileManager) throws {
        switch self {
        case .forward, .redo:
            try step.applyUndo(fileManager: fileManager)
        case .undo:
            try step.applyRedo(fileManager: fileManager)
        }
    }

    func syncStarredItems(for step: FolderBrowserMutationStep) {
        switch self {
        case .forward:
            step.syncStarredItemsAfterForward()
        case .undo:
            step.syncStarredItemsAfterUndo()
        case .redo:
            step.syncStarredItemsAfterRedo()
        }
    }

    func rollbackStarredItems(for step: FolderBrowserMutationStep) {
        switch self {
        case .forward, .redo:
            step.syncStarredItemsAfterUndo()
        case .undo:
            step.syncStarredItemsAfterRedo()
        }
    }
}

private func moveItem(
    from sourceURL: URL,
    to destinationURL: URL,
    fileManager: FileManager
) throws {
    let source = sourceURL.standardizedFileURL
    let destination = destinationURL.standardizedFileURL
    guard source != destination else { return }

    try ensureItemExists(at: source, fileManager: fileManager)
    try ensureTargetIsAvailable(at: destination, fileManager: fileManager)

    try withSecurityScopedAccess([source, destination.deletingLastPathComponent()]) {
        try fileManager.moveItem(at: source, to: destination)
    }
}

private func copyItem(
    from sourceURL: URL,
    to destinationURL: URL,
    fileManager: FileManager
) throws {
    let source = sourceURL.standardizedFileURL
    let destination = destinationURL.standardizedFileURL

    try ensureItemExists(at: source, fileManager: fileManager)
    try ensureTargetIsAvailable(at: destination, fileManager: fileManager)

    try withSecurityScopedAccess([source, destination.deletingLastPathComponent()]) {
        try fileManager.copyItem(at: source, to: destination)
    }
}

private func restoreFromTrash(
    trashedURL: URL,
    to destinationURL: URL,
    fileManager: FileManager
) throws {
    let source = trashedURL.standardizedFileURL
    let destination = destinationURL.standardizedFileURL

    try ensureItemExists(at: source, fileManager: fileManager)
    try ensureTargetIsAvailable(at: destination, fileManager: fileManager)

    try withSecurityScopedAccess([source, destination.deletingLastPathComponent()]) {
        try fileManager.moveItem(at: source, to: destination)
    }
}

@discardableResult
private func trashItem(at itemURL: URL, fileManager: FileManager) throws -> URL {
    let item = itemURL.standardizedFileURL
    try ensureItemExists(at: item, fileManager: fileManager)

    var resultingItemURL: NSURL?
    try withSecurityScopedAccess([item]) {
        try fileManager.trashItem(at: item, resultingItemURL: &resultingItemURL)
    }

    guard let trashURL = resultingItemURL as URL? else {
        throw folderBrowserError(
            "File operation failed because Trash did not return a resulting path for '\(item.lastPathComponent)'."
        )
    }

    return trashURL.standardizedFileURL
}

private func ensureItemExists(at url: URL, fileManager: FileManager) throws {
    guard fileManager.fileExists(atPath: url.path) else {
        throw folderBrowserError("File not found at path: \(url.path)")
    }
}

private func ensureTargetIsAvailable(at url: URL, fileManager: FileManager) throws {
    guard !fileManager.fileExists(atPath: url.path) else {
        throw folderBrowserError("Operation blocked because this path already exists: \(url.path)")
    }
}

private func withSecurityScopedAccess<T>(
    _ urls: [URL],
    operation: () throws -> T
) rethrows -> T {
    let uniqueURLs = Array(Set(urls.map { $0.standardizedFileURL }))
    var scopedURLs: [URL] = []
    scopedURLs.reserveCapacity(uniqueURLs.count)

    for url in uniqueURLs where url.startAccessingSecurityScopedResource() {
        scopedURLs.append(url)
    }

    defer {
        for url in scopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    return try operation()
}

private func folderBrowserError(_ message: String) -> NSError {
    NSError(
        domain: "FolderBrowser",
        code: 10,
        userInfo: [NSLocalizedDescriptionKey: message]
    )
}
