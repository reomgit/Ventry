import SwiftUI

struct MultipleInstallationsView: View {
    let baseName: String
    let installations: [ApplicationManager.DetectedApplication]
    let onSelectionMade: (ApplicationManager.DetectedApplication) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedInstallation: ApplicationManager.DetectedApplication?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Multiple Installations Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Ventry found multiple installations of \(baseName). Please select which one you'd like to use:")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(installations, id: \.installationPath) { installation in
                    InstallationRow(
                        installation: installation,
                        isSelected: selectedInstallation?.installationPath == installation.installationPath
                    ) {
                        selectedInstallation = installation
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Spacer()
                
                Button("Select Installation") {
                    if let selected = selectedInstallation {
                        onSelectionMade(selected)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedInstallation == nil)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .onAppear {
            // Select the first installation by default
            selectedInstallation = installations.first
        }
    }
}

struct InstallationRow: View {
    let installation: ApplicationManager.DetectedApplication
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(installation.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let version = installation.version {
                            Text("Version \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(installation.installationPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    MultipleInstallationsView(
        baseName: "Adobe After Effects",
        installations: [
            ApplicationManager.DetectedApplication(
                name: "Adobe After Effects 2024",
                version: "24.0.1",
                bundleIdentifier: "com.adobe.AfterEffects",
                appURL: URL(fileURLWithPath: "/Applications/Adobe After Effects 2024"),
                installationPath: "/Applications/Adobe After Effects 2024"
            ),
            ApplicationManager.DetectedApplication(
                name: "Adobe After Effects 2025",
                version: "25.0.0",
                bundleIdentifier: "com.adobe.AfterEffects",
                appURL: URL(fileURLWithPath: "/Applications/Adobe After Effects 2025"),
                installationPath: "/Applications/Adobe After Effects 2025"
            )
        ],
        onSelectionMade: { _ in }
    )
}
