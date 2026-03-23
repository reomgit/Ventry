import AppKit
import Foundation

enum FolderBrowserClipboardOperation {
    case copy
    case cut
}

struct FolderBrowserPasteRequest {
    let urls: [URL]
    let preferMove: Bool
}

@MainActor
final class FolderBrowserClipboardController {
    static let shared = FolderBrowserClipboardController()

    private let pasteboard = NSPasteboard.general
    private var lastInternalChangeCount: Int?
    private var lastInternalOperation: FolderBrowserClipboardOperation?

    private init() {}

    var hasPasteableFileURLs: Bool {
        currentPasteRequest() != nil
    }

    func write(urls: [URL], operation: FolderBrowserClipboardOperation) {
        let normalizedURLs = deduplicatedStandardizedURLs(from: urls)
        guard !normalizedURLs.isEmpty else { return }

        pasteboard.clearContents()
        pasteboard.writeObjects(normalizedURLs as [NSURL])
        lastInternalChangeCount = pasteboard.changeCount
        lastInternalOperation = operation
    }

    func currentPasteRequest() -> FolderBrowserPasteRequest? {
        clearInternalTrackingIfPasteboardChanged()

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return nil
        }

        let normalizedURLs = deduplicatedStandardizedURLs(from: urls)
        guard !normalizedURLs.isEmpty else { return nil }

        return FolderBrowserPasteRequest(
            urls: normalizedURLs,
            preferMove: lastInternalOperation == .cut
        )
    }

    func finalizePaste(_ request: FolderBrowserPasteRequest, didMutate: Bool) {
        guard didMutate, request.preferMove else { return }

        pasteboard.clearContents()
        resetInternalTracking()
    }

    private func clearInternalTrackingIfPasteboardChanged() {
        guard let lastInternalChangeCount else { return }
        guard lastInternalChangeCount != pasteboard.changeCount else { return }
        resetInternalTracking()
    }

    private func resetInternalTracking() {
        lastInternalChangeCount = nil
        lastInternalOperation = nil
    }

    private func deduplicatedStandardizedURLs(from urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()
        var results: [URL] = []

        for url in urls {
            let standardizedURL = url.standardizedFileURL
            if seenPaths.insert(standardizedURL.path).inserted {
                results.append(standardizedURL)
            }
        }

        return results
    }
}
