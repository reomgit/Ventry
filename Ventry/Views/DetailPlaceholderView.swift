import SwiftUI

struct DetailPlaceholderView: View {
    var title: String = "Choose a collection or shortcut"
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.forward.dottedline")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(title)
                .foregroundColor(.secondary)
                .font(.title2)

            if let message, !message.isEmpty {
                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
