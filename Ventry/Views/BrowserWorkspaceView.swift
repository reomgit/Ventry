import SwiftUI

struct BrowserWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var workspace: BrowserWorkspace

    var body: some View {
        Group {
            if let activeTab = workspace.activeTab {
                if activeTab.session.isPlaceholder {
                    DetailPlaceholderView(
                        title: "Choose a collection or shortcut",
                        message: "Select a folder from the sidebar to open it in this tab."
                    )
                } else {
                    FolderBrowserView(
                        session: activeTab.session,
                        onReturnToParentPage: returnHandler(for: activeTab.session.route)
                    )
                }
            } else {
                DetailPlaceholderView(
                    title: "No Tabs Open",
                    message: "Create a new tab or select a folder from the sidebar."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func returnHandler(for route: BrowserRoute) -> (() -> Void)? {
        guard let target = route.parentDetailTarget else {
            return nil
        }

        return {
            appState.detailMode = target
        }
    }
}

struct BrowserTabStripView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var workspace: BrowserWorkspace

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workspace.tabs) { tab in
                        BrowserTabItemView(
                            session: tab.session,
                            isActive: workspace.activeTabID == tab.id,
                            onSelect: {
                                appState.selectBrowserTab(tab.id)
                            },
                            onClose: {
                                appState.closeBrowserTab(tab.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            Divider()
                .frame(height: 18)

            Button(action: appState.createEmptyBrowserTab) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .help("New Tab")
        }
        .frame(height: 44)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct BrowserTabItemView: View {
    @ObservedObject var session: FolderBrowserSession
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                Text(session.displayTitle)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Tab")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 140, maxWidth: 220)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}
