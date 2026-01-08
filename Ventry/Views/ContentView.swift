//
//  ContentView.swift
//  Ventry
//
//  Created by Reom Nagasaka on 9/9/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
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
                Text("Choose a collection or shortcut")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
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
