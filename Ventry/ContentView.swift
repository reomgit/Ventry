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
        NavigationSplitView {
            SidebarView()
        } detail: {
            if let selectedCollection = appState.selectedCollection {
                AssetGridView(collection: selectedCollection)
            } else {
                Text("Select a collection to view assets")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .navigationSplitViewColumnWidth(
            min: 200,
            ideal: 250,
            max: 300
        )
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
