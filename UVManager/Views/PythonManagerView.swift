import SwiftUI

struct PythonManagerView: View {
  @EnvironmentObject var uvManager: UVManager
  @State private var searchText = ""
  @State private var showInstallSheet = false
  @State private var runtimeToInstall: UVPythonRuntime?
  @State private var runtimeToUninstall: UVPythonRuntime?
  @State private var showTerminalOutput = false

  private var installedRuntimes: [UVPythonRuntime] {
    filtered(uvManager.pythonRuntimes.filter { $0.isInstalled && $0.isUvManaged })
      .sorted { lhs, rhs in
        if lhs.isActive != rhs.isActive {
          return lhs.isActive
        }

        return lhs.version.compare(rhs.version, options: .numeric) == .orderedDescending
      }
  }

  private var systemRuntimes: [UVPythonRuntime] {
    filtered(uvManager.pythonRuntimes.filter { $0.isInstalled && $0.isSystemPython })
  }

  private var downloadableRuntimes: [UVPythonRuntime] {
    filtered(uvManager.pythonRuntimes.filter { $0.isDownloadAvailable && !$0.isInstalled })
  }

  var body: some View {
    VStack(spacing: 0) {
      filterBar

      Divider()

      if uvManager.isPythonLoading && uvManager.pythonRuntimes.isEmpty {
        ProgressView("Loading Python versions...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          runtimeSection(
            title: "System Python",
            runtimes: systemRuntimes,
            emptyMessage: searchText.isEmpty
              ? "No system Python installs found." : "No matching system Python installs.",
            footer:
              "These installs are outside uv's managed runtime directory and are shown for context."
          )

          runtimeSection(
            title: "Installed",
            runtimes: installedRuntimes,
            emptyMessage: "No uv-managed Python versions found."
          )

          runtimeSection(
            title: "Available to Download",
            runtimes: downloadableRuntimes,
            emptyMessage: searchText.isEmpty
              ? "No downloadable Python versions found."
              : "No matching downloadable Python versions.",
            onInstall: { runtime in
              runtimeToInstall = runtime
              showInstallSheet = true
            }
          )
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
      }
    }
    .navigationTitle("Python Versions")
    .navigationSubtitle("uv python list")
    .sheet(isPresented: $showInstallSheet) {
      PythonInstallView(initialRuntime: runtimeToInstall)
    }
    .onChange(of: showInstallSheet) { _, isPresented in
      if !isPresented {
        runtimeToInstall = nil
      }
    }
    .sheet(isPresented: $showTerminalOutput) {
      EnhancedTerminalView(processManager: uvManager.processManager)
        .frame(width: 760, height: 520)
    }
    .alert("Uninstall Python", isPresented: uninstallAlertIsPresented) {
      Button("Cancel", role: .cancel) {}
      Button("Uninstall", role: .destructive) {
        guard let runtime = runtimeToUninstall else { return }
        Task {
          do {
            try await uvManager.uninstallPython(target: runtime.target)
            showTerminalOutput = true
          } catch {
            await MainActor.run {
              uvManager.lastError = error.localizedDescription
            }
          }
        }
      }
    } message: {
      if let runtime = runtimeToUninstall {
        Text(
          "Uninstall \(runtime.displayName)? This removes the uv-managed Python runtime for \(runtime.target)."
        )
      }
    }
    .task {
      if uvManager.pythonRuntimes.isEmpty {
        await uvManager.fetchPythonRuntimes()
      }
    }
  }

  private var filterBar: some View {
    HStack(spacing: 12) {
      TextField("Filter by version, implementation, target, or path", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 480)

      Spacer()

      Button {
        Task {
          await uvManager.fetchPythonRuntimes()
        }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
      .disabled(uvManager.isPythonLoading)
      .help("Refresh Python versions")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
  }

  @ViewBuilder
  private func runtimeSection(
    title: String,
    runtimes: [UVPythonRuntime],
    emptyMessage: String,
    footer: String? = nil,
    onInstall: ((UVPythonRuntime) -> Void)? = nil
  ) -> some View {
    Section {
      if runtimes.isEmpty {
        Text(emptyMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
      } else {
        ForEach(runtimes) { runtime in
          PythonRuntimeRow(runtime: runtime) {
            runtimeToUninstall = runtime
          } onInstall: {
            onInstall?(runtime)
          }
        }
      }
    } header: {
      HStack {
        Text(title)

        Text("\(runtimes.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())
      }
    } footer: {
      if let footer, !runtimes.isEmpty {
        Text(footer)
      }
    }
  }

  private func filtered(_ runtimes: [UVPythonRuntime]) -> [UVPythonRuntime] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return runtimes }
    return runtimes.filter { $0.searchableText.contains(query) }
  }

  private var uninstallAlertIsPresented: Binding<Bool> {
    Binding(
      get: { runtimeToUninstall != nil },
      set: { isPresented in
        if !isPresented {
          runtimeToUninstall = nil
        }
      }
    )
  }
}

private struct PythonRuntimeRow: View {
  let runtime: UVPythonRuntime
  let onUninstall: () -> Void
  let onInstall: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: runtime.isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
        .font(.body)
        .foregroundStyle(runtime.isInstalled ? Color.green : Color.accentColor)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text(runtime.displayName)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(1)

          StatusBadge(text: runtime.implementationDisplayName, color: .secondary)

          if runtime.isFreethreaded {
            StatusBadge(text: "Free-threaded", color: .purple)
          }

          if runtime.isActive {
            StatusBadge(text: "Active", color: .green)
          }

          if runtime.isEndOfLife {
            Link(destination: URL(string: "https://devguide.python.org/versions/")!) {
              StatusBadge(text: "End-of-Life", color: .red)
            }
            .buttonStyle(.plain)
            .help("View Python version status")
          }
        }

        Text(runtime.target)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)

        if let firstLocation = runtime.installedLocations.first {
          Text(locationSummary(firstLocation))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
        }
      }

      Spacer(minLength: 12)

      HStack(spacing: 8) {
        if runtime.isInstalled {
          StatusBadge(
            text: runtime.installSourceLabel, color: runtime.installSourceBadgeColor)
        }

        if runtime.installedLocations.count > 1 {
          Text("+\(runtime.installedLocations.count - 1) links")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        if runtime.isUvManaged {
          Button(role: .destructive, action: onUninstall) {
            Label("Uninstall", systemImage: "trash")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .disabled(runtime.isActive)
          .help(uninstallHelpText)
        }

        if !runtime.isInstalled && runtime.isDownloadAvailable {
          Button(action: onInstall) {
            Label("Install", systemImage: "arrow.down.circle")
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .help("Install \(runtime.displayName)")
        }
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }

  private func locationSummary(_ location: String) -> String {
    if let aliasTarget = runtime.installedEntries.first(where: { $0.location == location })?
      .aliasTarget
    {
      return
        "\(runtime.installedEntries.first(where: { $0.location == location })?.executablePath ?? location) -> \(aliasTarget)"
    }
    return location
  }

  private var uninstallHelpText: String {
    if runtime.isActive {
      return
        "Cannot uninstall the active Python because uv tool install environments may depend on it."
    }

    return "Uninstall \(runtime.displayName)"
  }
}

extension UVPythonRuntime {
  fileprivate var installSourceBadgeColor: Color {
    if isUvManaged {
      return .green
    }

    if isSystemPython {
      return .blue
    }

    return .orange
  }
}
