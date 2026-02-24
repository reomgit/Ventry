import Foundation
import CoreTransferable

struct FolderBrowserDraggedItem: Transferable, Identifiable {
    let url: URL

    var id: URL {
        url
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.url)
    }
}

