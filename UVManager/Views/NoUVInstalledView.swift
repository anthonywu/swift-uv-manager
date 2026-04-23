import SwiftUI

struct NoUVInstalledView: View {
  @EnvironmentObject var uvManager: UVManager
  @State private var isInstalling = false

  var body: some View {
    VStack(spacing: 16) {
      ContentUnavailableView {
        Label("UV Not Found", systemImage: "exclamationmark.triangle")
      } description: {
        Text("Install uv to manage Python tools and runtimes from UV Manager.")
      } actions: {
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
          Label("Install uv", systemImage: "arrow.down.circle")
            .frame(minWidth: 120)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isInstalling)
      }

      if isInstalling {
        ProgressView("Installing uv...")
          .progressViewStyle(.circular)
      }

      Link("Learn more about uv", destination: URL(string: "https://github.com/astral-sh/uv")!)
        .font(.caption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
