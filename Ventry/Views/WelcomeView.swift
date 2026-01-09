import SwiftUI
import AppKit

struct WelcomeView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var isAnimating = false
    
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
                
                Text("To manage your applications and assets, Ventry needs access to your Applications folder.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 400)
            }
            
            Button(action: {
                Task {
                    _ = await permissionManager.requestApplicationsDirectoryAccess()
                }
            }) {
                HStack {
                    Image(systemName: "lock.open.fill")
                    Text("Grant Access")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 160)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)
            
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
}

#Preview {
    WelcomeView()
}
