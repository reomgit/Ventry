import SwiftUI
import AppKit

struct WelcomeView: View {
    @State private var isAnimating = false
    @State private var isSettingUp = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon or Logo
            Image(systemName: "folder.badge.gearshape")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.bounce, value: isAnimating)
            
            VStack(spacing: 16) {
                Text("Welcome to Ventry")
                    .font(.system(size: 32, weight: .bold))

                Text("Ventry keeps its internal data in Application Support, and creates your Design Assets workspace in Documents so it is easy to find in Finder.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 500)

                Text("Protected folders can still trigger macOS privacy prompts when needed, but Ventry will first try to create the Documents-based Design Assets folder automatically.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 500)
            }

            Button(action: {
                isSettingUp = true
                Task {
                    await performSetup()
                    isSettingUp = false
                }
            }) {
                HStack {
                    if isSettingUp {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Image(systemName: "checkmark.circle.fill")
                    Text("Prepare Storage")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 200)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)
            .disabled(isSettingUp)
            
            Spacer()
            
            Text("Ventry respects your privacy and asks macOS for folder access only when it is needed.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isAnimating = true
        }
    }

    private func performSetup() async {
        await MainActor.run {
            _ = AppStorageManager.shared.prepareDirectories()
            PermissionManager.shared.refreshPermissionState()
        }
    }
}

#Preview {
    WelcomeView()
}
