import SwiftUI

struct SystemInfoView: View {
  @EnvironmentObject var uvManager: UVManager
  @State private var showPruneAlert = false
  @State private var showTerminalOutput = false

  var body: some View {
    VStack(spacing: 0) {
      topBar

      Divider()

      Form {
        directoriesSection
        maintenanceSection
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
    }
    .navigationTitle("UV System Info")
    .navigationSubtitle("uv tool dir · uv cache")
    .task {
      if uvManager.toolsDirectory.isEmpty || uvManager.cacheDirectory.isEmpty
        || uvManager.cacheSizeBytes == nil
      {
        await fetchSystemInfo()
      }
    }
    .sheet(isPresented: $showTerminalOutput) {
      EnhancedTerminalView(processManager: uvManager.processManager)
        .frame(width: 760, height: 520)
    }
    .onChange(of: uvManager.processManager.isRunning) { _, isRunning in
      guard !isRunning, showTerminalOutput, lastCommandWasCachePrune else { return }
      Task {
        await uvManager.fetchCacheInfo()
      }
    }
    .alert("Prune UV Cache", isPresented: $showPruneAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Prune", role: .destructive) {
        pruneCache()
      }
    } message: {
      Text(
        "Remove all unreachable objects from the uv cache? Objects still referenced by uv are kept."
      )
    }
  }

  private var topBar: some View {
    HStack {
      Text("Directories and cache maintenance for the selected uv installation.")
        .font(.callout)
        .foregroundStyle(.secondary)

      Spacer()

      Button {
        Task {
          await fetchSystemInfo()
        }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
      .disabled(uvManager.isCacheLoading)
      .help("Refresh uv system information")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var directoriesSection: some View {
    Section("Directories") {
      CacheInfoRow(
        title: "Tools Directory",
        value: toolsDirectoryDisplay,
        detail: nil,
        systemImage: "folder"
      )

      CacheInfoRow(
        title: "Cache Directory",
        value: cacheDirectoryDisplay,
        detail: nil,
        systemImage: "externaldrive"
      )

      CacheInfoRow(
        title: "Cache Size",
        value: cacheSizeDisplay,
        detail: cacheSizeByteDisplay,
        systemImage: "chart.bar.xaxis"
      )
    }
  }

  private var maintenanceSection: some View {
    Section("Maintenance") {
      if let installation = uvManager.selectedInstallation {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text("uv \(installation.version)")
              .font(.body)
              .fontWeight(.medium)

            Text(installation.path)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
              .textSelection(.enabled)
          }

          Spacer()

          Button {
            showTerminalOutput = true
            Task {
              await uvManager.selfUpdate()
            }
          } label: {
            Label("Update uv", systemImage: "arrow.up.circle")
              .frame(minWidth: 120)
          }
          .buttonStyle(.bordered)
          .disabled(uvManager.processManager.isRunning)
        }
      }

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Cache")
            .font(.body)
            .fontWeight(.medium)

          Text("Prune unreachable cache objects while keeping entries still referenced by uv.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button(role: .destructive) {
          showPruneAlert = true
        } label: {
          Label("Prune Cache", systemImage: "trash")
            .frame(minWidth: 120)
        }
        .buttonStyle(.bordered)
        .disabled(uvManager.selectedInstallation == nil || uvManager.processManager.isRunning)

        if uvManager.isCacheLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.8)
        }
      }
    }
  }

  private var toolsDirectoryDisplay: String {
    if !uvManager.toolsDirectory.isEmpty {
      return uvManager.toolsDirectory
    }

    return uvManager.isLoading ? "Loading..." : "Unavailable"
  }

  private var cacheDirectoryDisplay: String {
    if !uvManager.cacheDirectory.isEmpty {
      return uvManager.cacheDirectory
    }

    return uvManager.isCacheLoading ? "Loading..." : "Unavailable"
  }

  private var cacheSizeDisplay: String {
    guard let bytes = uvManager.cacheSizeBytes else {
      return uvManager.isCacheLoading ? "Loading..." : "Unavailable"
    }

    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  private var cacheSizeByteDisplay: String? {
    guard let bytes = uvManager.cacheSizeBytes else { return nil }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let value = formatter.string(from: NSNumber(value: bytes)) ?? "\(bytes)"
    return "\(value) bytes"
  }

  private var lastCommandWasCachePrune: Bool {
    guard let command = uvManager.processManager.lastCommand else { return false }
    return command.arguments == ["cache", "prune"]
  }

  private func fetchSystemInfo() async {
    await uvManager.fetchToolsDirectory()
    await uvManager.fetchCacheInfo()
  }

  private func pruneCache() {
    Task {
      do {
        try await uvManager.pruneCache()
        showTerminalOutput = true
      } catch {
        uvManager.lastError = error.localizedDescription
      }
    }
  }
}

private struct CacheInfoRow: View {
  let title: String
  let value: String
  let detail: String?
  let systemImage: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.body)
        .foregroundStyle(.secondary)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(value)
          .font(isDirectoryRow ? .system(.body, design: .monospaced) : .title2)
          .fontWeight(isDirectoryRow ? .regular : .semibold)
          .lineLimit(isDirectoryRow ? 2 : 1)
          .truncationMode(.middle)
          .textSelection(.enabled)

        if let detail {
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      Spacer(minLength: 12)
    }
    .padding(.vertical, 4)
  }

  private var isDirectoryRow: Bool {
    title.localizedCaseInsensitiveContains("Directory")
  }
}
