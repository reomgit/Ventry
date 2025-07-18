import SwiftUI

enum SidebarSection: Identifiable, Hashable {
    case favorites
    case presets
    case userLibrary
    case application(DetectedApp)

    var id: String {
        switch self {
        case .favorites: return "Favorites"
        case .presets: return "Presets"
        case .userLibrary: return "User Library"
        case .application(let app): return "app-\(app.name)"
        }
    }

    var label: String {
        switch self {
        case .favorites: return "Favorites"
        case .presets: return "Presets"
        case .userLibrary: return "User Library"
        case .application(let app): return app.name
        }
    }
}

struct DetectedApp: Identifiable, Hashable {
    let name: String
    let folders: [String] = ["Fonts", "Icons", "Colors", "Photos"]
    var id: String { name }
}

struct ContentView: View {
    @State private var selectedItem: SidebarSection?
    @State private var apps: [DetectedApp] = [
        DetectedApp(name: "Premiere Pro"),
        DetectedApp(name: "After Effects")
    ]

    var sidebarItems: [SidebarSection] {
        var items: [SidebarSection] = [
            .favorites,
            .presets,
            .userLibrary
        ]
        items.append(contentsOf: apps.map { SidebarSection.application($0) })
        return items
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section {
                    sidebarButton(for: .favorites)
                    sidebarButton(for: .presets)
                    sidebarButton(for: .userLibrary)
                }

                Section(header: Text("Applications")) {
                    ForEach(apps, id: \.id) { app in
                        sidebarButton(for: .application(app))
                    }
                }
            }
            .listStyle(SidebarListStyle())
        } detail: {
            if let selected = selectedItem {
                switch selected {
                case .application(let app):
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                            ForEach(app.folders, id: \.self) { folder in
                                VStack {
                                    Image(systemName: "folder.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.accentColor)
                                    Text(folder)
                                        .font(.caption)
                                }
                                .frame(width: 100, height: 100)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Open in Finder") {
                                // Placeholder for Finder logic
                            }
                        }
                    }

                default:
                    Text("You selected \(selected.label)")
                        .font(.title)
                        .padding()
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                }
            } else {
                Text("Select an item from the sidebar")
                    .foregroundColor(.secondary)
                    .font(.title2)
                    .padding()
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
            }
        }
    }

    @ViewBuilder
    private func sidebarButton(for section: SidebarSection) -> some View {
        let isSelected = selectedItem == section
        Text(section.label)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedItem = section
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
