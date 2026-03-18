import SwiftUI

struct FolderBrowserItemIconView: View {
    let item: FolderBrowserItem
    let size: CGFloat
    var showCreativeBadge: Bool = false
    var showStarBadge: Bool = false

    var body: some View {
        Image(nsImage: FolderBrowserIconProvider.shared.icon(for: item, pointSize: size))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) {
                if showStarBadge {
                    Image(systemName: "star.fill")
                        .font(.system(size: max(8, size * 0.22), weight: .semibold))
                        .foregroundStyle(.yellow)
                        .padding(2)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                        )
                        .offset(x: 4, y: -4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showCreativeBadge, let badge = FolderBrowserIconProvider.shared.badge(for: item) {
                    FolderBrowserCreativeBadgeView(badge: badge)
                        .offset(x: 2, y: 2)
                }
            }
    }
}

private struct FolderBrowserCreativeBadgeView: View {
    let badge: FolderBrowserCreativeBadge

    var body: some View {
        Text(badge.label)
            .font(.system(size: 6, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(Color(nsColor: badge.color))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
            )
    }
}
