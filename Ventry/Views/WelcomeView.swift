import SwiftUI
import AppKit

struct WelcomeView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var isAnimating = false
    @State private var setupStep = 1  // 1 = Applications, 2 = Documents
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

                if setupStep == 1 {
                    Text("To manage your applications and assets, Ventry needs access to your Applications folder.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 400)
                } else {
                    Text("Ventry also needs access to your Documents folder to store collections and design assets.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 400)
                }

                Text("After granting access, Ventry will validate all required paths including your Applications folder, Collections, and design asset directories to ensure everything works correctly.")
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
                    Image(systemName: setupStep == 1 ? "lock.open.fill" : "folder.badge.plus")
                    Text(setupStep == 1 ? "Grant Applications Access" : "Grant Documents Access")
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
            
            Text("Ventry respects your privacy and only accesses the folders you select.")
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
        if setupStep == 1 {
            // Step 1: Request Applications access
            let success = await permissionManager.requestApplicationsDirectoryAccess()
            if success {
                // Move to step 2
                await MainActor.run {
                    setupStep = 2
                }
            }
        } else if setupStep == 2 {
            // Step 2: Request Documents access and create Design Assets folder
            if let documentsURL = await permissionManager.requestDocumentsAccess() {
                // Create Ventry/Design Assets folder structure
                let ventryURL = documentsURL.appendingPathComponent("Ventry")
                let collectionsURL = ventryURL.appendingPathComponent("Collections")
                let designAssetsURL = ventryURL.appendingPathComponent("Design Assets")

                do {
                    // Create directories with intermediate directories
                    try FileManager.default.createDirectory(at: collectionsURL, withIntermediateDirectories: true)
                    try FileManager.default.createDirectory(at: designAssetsURL, withIntermediateDirectories: true)

                    print("✅ Created Ventry directories:")
                    print("  - \(collectionsURL.path)")
                    print("  - \(designAssetsURL.path)")
                } catch {
                    print("❌ Failed to create Ventry directories: \(error)")
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
