import SwiftUI

struct FolderBrowserToolbar: View {
    @ObservedObject var viewModel: FolderBrowserViewModel
    @Binding var viewMode: BrowserViewMode
    @Binding var sortOrder: SortOrder

    var body: some View {
        HStack(spacing: 0) {
            // Navigation controls
            HStack(spacing: 4) {
                Button(action: viewModel.navigateBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canNavigateBack)
                .help("Go Back")

                Button(action: viewModel.navigateForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canNavigateForward)
                .help("Go Forward")

                Button(action: viewModel.navigateUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Go to Parent Folder")
            }
            .padding(.leading, 8)

            Divider()
                .padding(.horizontal, 8)

            // Breadcrumb navigation
            BreadcrumbView(viewModel: viewModel)

            Spacer()

            // View controls
            HStack(spacing: 4) {
                // Sort menu
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: {
                            sortOrder = order
                        }) {
                            HStack {
                                Text(order.rawValue)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Sort Options")

                Divider()
                    .frame(height: 16)

                // View mode buttons
                Button(action: { viewMode = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(viewMode == .grid ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .help("Grid View")

                Button(action: { viewMode = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(viewMode == .list ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .help("List View")

                Button(action: { viewMode = .column }) {
                    Image(systemName: "rectangle.grid.1x2")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(viewMode == .column ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .help("Column View")
            }
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct BreadcrumbView: View {
    @ObservedObject var viewModel: FolderBrowserViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, component in
                    HStack(spacing: 4) {
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            viewModel.navigateToBreadcrumb(at: index + 1) // +1 because of root
                        }) {
                            Text(component)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(index == viewModel.breadcrumbs.count - 1 ? .primary : .secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

/// View mode enum for browser
enum BrowserViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    case column = "Column"
}
