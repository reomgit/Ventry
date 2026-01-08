import SwiftUI

struct ApplicationInstallationFlowView: View {
    let detectedApps: [DetectedApplication]
    let supportedApps: [String: SupportedApplication]
    let onComplete: ([Application]) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var currentAppIndex = 0
    @State private var installedApplications: [Application] = []
    @State private var isFlowComplete = false

    var body: some View {
        VStack {
            if isFlowComplete {
                InstallationCompleteView(
                    installedApps: installedApplications,
                    totalApps: detectedApps.count,
                    onFinish: {
                        onComplete(installedApplications)
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else if currentAppIndex < detectedApps.count {
                let currentApp = detectedApps[currentAppIndex]
                let isSupported = supportedApps[currentApp.bundleIdentifier] != nil

                IndividualAppInstallationView(
                    detectedApp: currentApp,
                    isSupported: isSupported,
                    currentAppIndex: currentAppIndex,
                    totalApps: detectedApps.count,
                    onInstall: { configuredApp in
                        installApplication(configuredApp)
                    },
                    onSkip: {
                        skipCurrentApp()
                    },
                    onCancel: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func installApplication(_ configuredApp: DetectedApplication) {
        let selectedDirectories = configuredApp.availableDirectories
            .filter { $0.isSelected }
            .map { AppDirectory(name: $0.name, path: $0.path, type: $0.type) }

        let application = Application(
            name: configuredApp.name,
            bundleIdentifier: configuredApp.bundleIdentifier,
            bundlePath: configuredApp.bundlePath,
            directories: selectedDirectories
        )

        installedApplications.append(application)
        moveToNextApp()
    }

    private func skipCurrentApp() {
        moveToNextApp()
    }

    private func moveToNextApp() {
        currentAppIndex += 1
        if currentAppIndex >= detectedApps.count {
            isFlowComplete = true
        }
    }
}

struct InstallationCompleteView: View {
    let installedApps: [Application]
    let totalApps: Int
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Success icon and title
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Installation Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            // Summary
            VStack(spacing: 12) {
                Text("Successfully processed \(totalApps) applications")
                    .font(.headline)

                Text("\(installedApps.count) applications added to Ventry")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if installedApps.count < totalApps {
                    Text("\(totalApps - installedApps.count) applications were skipped")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Installed apps list
            if !installedApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added Applications:")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(installedApps) { app in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(app.directories.count) directories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }

            Button("Finish") {
                onFinish()
            }
            .buttonStyle(PrimaryButtonStyle())
            .font(.headline)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ApplicationInstallationFlowView(
        detectedApps: [
            DetectedApplication(
                name: "Test App 1",
                bundleIdentifier: "com.test.app1",
                bundlePath: "/Applications/Test App 1.app",
                availableDirectories: []
            ),
            DetectedApplication(
                name: "Test App 2",
                bundleIdentifier: "com.test.app2",
                bundlePath: "/Applications/Test App 2.app",
                availableDirectories: []
            )
        ],
        supportedApps: [:],
        onComplete: { _ in }
    )
}