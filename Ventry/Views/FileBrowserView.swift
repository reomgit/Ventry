// This file now redirects to the new FolderBrowserView implementation
// The old implementation has been preserved in FileBrowserView_old.swift

import SwiftUI

/// Compatibility wrapper to redirect to the new FolderBrowserView
struct FileBrowserView: View {
    let title: String
    let path: String

    var body: some View {
        FolderBrowserView(title: title, path: path)
    }
}
