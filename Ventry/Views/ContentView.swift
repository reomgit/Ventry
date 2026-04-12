//
//  ContentView.swift
//  Ventry
//
//  Created by Reom Nagasaka on 9/9/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var permissionManager = PermissionManager.shared

    var body: some View {
        GeometryReader { geometry in
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(
                        min: 200,
                        ideal: min(250, geometry.size.width * 0.35),
                        max: max(250, min(300, geometry.size.width * 0.35))
                    )
            } detail: {
                VStack(spacing: 0) {
                    BrowserTabStripView(workspace: appState.browserWorkspace)

                    Divider()

                    detailView
                }
            }
            .focusedSceneValue(\.browserTabCommandHandler, browserTabCommandHandler)
            .navigationSplitViewStyle(.balanced)
        }
        .sheet(isPresented: $appState.showingMultipleInstallationsSheet) {
            if let (baseName, installations) = appState.pendingInstallationSelection {
                MultipleInstallationsView(
                    baseName: baseName,
                    installations: installations
                ) { selectedApp in
                    appState.selectApplicationInstallation(selectedApp)
                }
            }
        }
        .sheet(isPresented: $permissionManager.needsPathRevalidation) {
            PathValidationView()
        }
    }

    private var browserTabCommandHandler: BrowserTabCommandHandler {
        BrowserTabCommandHandler(
            canCreateNewTab: { true },
            canCloseActiveTab: { appState.browserWorkspace.hasTabs },
            canSelectPreviousTab: { appState.browserWorkspace.canSelectPreviousTab },
            canSelectNextTab: { appState.browserWorkspace.canSelectNextTab },
            createNewTab: { appState.createEmptyBrowserTab() },
            closeActiveTab: { appState.closeActiveBrowserTab() },
            selectPreviousTab: { appState.selectPreviousBrowserTab() },
            selectNextTab: { appState.selectNextBrowserTab() }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.detailMode {
        case .placeholder:
            DetailPlaceholderView()
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedSidebarItem = nil
                }

        case .browserWorkspace:
            BrowserWorkspaceView(workspace: appState.browserWorkspace)

        case let .applicationDirectories(applicationId):
            ApplicationDirectoryView(applicationId: applicationId) { directory, application in
                appState.openApplicationDirectory(directory, in: application)
            }

        case .applicationSettings:
            ApplicationSettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
