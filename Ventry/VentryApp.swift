//
//  VentryApp.swift
//  Ventry
//
//  Created by Reom Nagasaka on 9/9/25.
//

import SwiftUI

@main
struct VentryApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
            .frame(minWidth: 800, minHeight: 600)
            .onAppear {
                _ = AppStorageManager.shared.prepareDirectories()
                PermissionManager.shared.refreshPermissionState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                PermissionManager.shared.refreshPermissionState()

                Task {
                    await appState.revalidatePaths()
                }
            }
        }
        .windowStyle(DefaultWindowStyle())
    }
}
