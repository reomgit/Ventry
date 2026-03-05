import SwiftUI

struct FolderBrowserItemIconView: View {
    let item: FolderBrowserItem
    let size: CGFloat
    var showCreativeBadge: Bool = false

    var body: some View {
        Image(nsImage: FolderBrowserIconProvider.shared.icon(for: item, pointSize: size))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
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
