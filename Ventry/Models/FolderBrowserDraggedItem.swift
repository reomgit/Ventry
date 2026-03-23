import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct FolderBrowserDraggedItem: Transferable, Identifiable {
    let url: URL

    var id: URL {
        url
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .folder) { item in
            SentTransferredFile(item.url, allowAccessingOriginalFile: true)
        }
        .exportingCondition { item in
            item.isDirectory
        }

        FileRepresentation(exportedContentType: .item) { item in
            SentTransferredFile(item.url, allowAccessingOriginalFile: true)
        }
        .exportingCondition { item in
            !item.isDirectory
        }

        ProxyRepresentation(exporting: \.url)
    }

    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}
