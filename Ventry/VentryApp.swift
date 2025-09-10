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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(DefaultWindowStyle())
    }
}
