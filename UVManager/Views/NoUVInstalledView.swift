import SwiftUI

struct NoUVInstalledView: View {
    @EnvironmentObject var uvManager: UVManager
    @State private var isInstalling = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("UV Not Found")
                .font(.title)
                .fontWeight(.bold)
            
            Text("UV is not installed on your system. UV is required to manage Python tools.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button {
                isInstalling = true
                Task {
                    do {
                        try await uvManager.installUV()
                    } catch {
                        print("Installation failed: \(error)")
                    }
                    isInstalling = false
                }
            } label: {
                Label("Install UV", systemImage: "arrow.down.circle.fill")
                    .frame(width: 200)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling)
            
            if isInstalling {
                ProgressView("Installing UV...")
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
            
            Link("Learn more about UV", destination: URL(string: "https://github.com/astral-sh/uv")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}