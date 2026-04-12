import Foundation
import SwiftUI
import Combine

enum DetailMode: Equatable {
    case placeholder
    case browserWorkspace
    case applicationDirectories(UUID)
    case applicationSettings
}

enum SidebarSelection: Equatable {
    case starred(UUID)
    case regularFolder(RegularFolder)
    case collection(UUID)
    case application(UUID)
    case applicationSettings
}

struct BrowserRoute: Equatable {
    var title: String
    var path: String?
    var initiallySelectedPath: String?
    var sourceApplicationId: UUID?
    var parentPageTitle: String?
    var parentDetailTarget: DetailMode?

    nonisolated init(
        title: String,
        path: String?,
        initiallySelectedPath: String? = nil,
        sourceApplicationId: UUID? = nil,
        parentPageTitle: String? = nil,
        parentDetailTarget: DetailMode? = nil
    ) {
        self.title = title
        self.path = path.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        self.initiallySelectedPath = initiallySelectedPath.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        }
        self.sourceApplicationId = sourceApplicationId
        self.parentPageTitle = parentPageTitle
        self.parentDetailTarget = parentDetailTarget
    }

    nonisolated static func empty(title: String = "New Tab") -> BrowserRoute {
        BrowserRoute(title: title, path: nil)
    }

    nonisolated var isPlaceholder: Bool {
        path == nil
    }
}

@MainActor
final class FolderBrowserSession: ObservableObject, Identifiable {
    let id = UUID()
    let viewModel = FolderBrowserViewModel()

    @Published private(set) var route: BrowserRoute
    @Published private(set) var sortOrder: SortOrder

    init(route: BrowserRoute, sortOrder: SortOrder = .nameAscending) {
        self.route = route
        self.sortOrder = sortOrder
        viewModel.setSortOrder(sortOrder)
        open(route)
    }

    var displayTitle: String {
        route.title
    }

    var isPlaceholder: Bool {
        route.isPlaceholder
    }

    func open(_ route: BrowserRoute) {
        self.route = route
        viewModel.setSortOrder(sortOrder)

        guard let path = route.path else {
            viewModel.resetState()
            return
        }

        viewModel.resetNavigation(
            to: URL(fileURLWithPath: path),
            selectingPath: route.initiallySelectedPath
        )
    }

    func updateSortOrder(_ sortOrder: SortOrder) {
        self.sortOrder = sortOrder
        viewModel.setSortOrder(sortOrder)
    }
}

@MainActor
struct BrowserTab: Identifiable {
    let id: UUID
    let session: FolderBrowserSession

    init(
        id: UUID = UUID(),
        route: BrowserRoute = .empty(),
        sortOrder: SortOrder = .nameAscending
    ) {
        self.id = id
        self.session = FolderBrowserSession(route: route, sortOrder: sortOrder)
    }
}

@MainActor
final class BrowserWorkspace: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published private(set) var activeTabID: UUID?

    var activeTab: BrowserTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    var hasTabs: Bool {
        !tabs.isEmpty
    }

    var canSelectPreviousTab: Bool {
        guard let activeTabIndex else { return false }
        return activeTabIndex > 0
    }

    var canSelectNextTab: Bool {
        guard let activeTabIndex else { return false }
        return activeTabIndex < tabs.count - 1
    }

    func createEmptyTab() {
        createTab(with: .empty())
    }

    func createTab(with route: BrowserRoute = .empty()) {
        let tab = BrowserTab(route: route)
        tabs.append(tab)
        activeTabID = tab.id
    }

    func open(_ route: BrowserRoute) {
        if let activeTabIndex {
            tabs[activeTabIndex].session.open(route)
            activeTabID = tabs[activeTabIndex].id
            return
        }

        createTab(with: route)
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    func selectPreviousTab() {
        guard let activeTabIndex, activeTabIndex > 0 else { return }
        activeTabID = tabs[activeTabIndex - 1].id
    }

    func selectNextTab() {
        guard let activeTabIndex, activeTabIndex < tabs.count - 1 else { return }
        activeTabID = tabs[activeTabIndex + 1].id
    }

    @discardableResult
    func closeActiveTab() -> Bool {
        guard let activeTabID else {
            return hasTabs
        }

        return closeTab(id: activeTabID)
    }

    @discardableResult
    func closeTab(id: UUID) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return hasTabs
        }

        tabs.remove(at: index)

        guard !tabs.isEmpty else {
            activeTabID = nil
            return false
        }

        if activeTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            activeTabID = tabs[nextIndex].id
        } else if activeTabID == nil {
            activeTabID = tabs[min(index, tabs.count - 1)].id
        }

        return true
    }

    private var activeTabIndex: Int? {
        if let activeTabID,
           let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
            return index
        }

        if !tabs.isEmpty {
            activeTabID = tabs[0].id
            return 0
        }

        return nil
    }
}
