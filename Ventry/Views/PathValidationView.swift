import SwiftUI

struct PathValidationView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.orange)

                Text("Some Paths Need Access")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Ventry detected paths that require permission. Grant access to these locations to ensure full functionality.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // List of invalid paths
            if !permissionManager.invalidPaths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inaccessible Paths:")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(permissionManager.invalidPaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.badge.questionmark")
                                        .foregroundStyle(.orange)
                                    Text(path)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Button("Fix") {
                                        Task {
                                            await requestAccessToPath(path)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button("Revalidate") {
                    Task {
                        await appState.revalidatePaths()
                        if permissionManager.invalidPaths.isEmpty {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button("Continue Anyway") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 550)
    }

    private func requestAccessToPath(_ path: String) async {
        let success = await permissionManager.requestAccessToPath(path)
        if success {
            await appState.revalidatePaths()
        }
    }
}

#Preview {
    PathValidationView()
        .environmentObject(AppState())
}
