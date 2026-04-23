import SwiftUI

struct PythonInstallView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var uvManager: UVManager

  let initialRuntime: UVPythonRuntime?

  @State private var query = ""
  @State private var selectedRuntime: UVPythonRuntime?
  @State private var setAsDefault = false
  @State private var upgradeExisting = false
  @State private var reinstallExisting = false
  @State private var compileBytecode = false
  @State private var showAdvanced = false
  @State private var isInstalling = false
  @State private var showTerminalOutput = false

  init(initialRuntime: UVPythonRuntime? = nil) {
    self.initialRuntime = initialRuntime
  }

  private var targetToInstall: String {
    selectedRuntime?.target ?? query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canUpgradeExisting: Bool {
    selectedRuntime?.isUvManaged == true && selectedRuntime?.upgradeTarget != nil
  }

  private var canReinstallExisting: Bool {
    selectedRuntime?.isUvManaged == true
  }

  private var commandTarget: String {
    if canUpgradeExisting && upgradeExisting, let upgradeTarget = selectedRuntime?.upgradeTarget {
      return upgradeTarget
    }

    return targetToInstall
  }

  private var commandPreview: String {
    guard !commandTarget.isEmpty else { return "" }

    var parts = ["uv", "python", "install"]

    if setAsDefault {
      parts.append("--default")
    }

    if canUpgradeExisting && upgradeExisting {
      parts.append("--upgrade")
    }

    if canReinstallExisting && reinstallExisting {
      parts.append("--reinstall")
    }

    if compileBytecode {
      parts.append("--compile-bytecode")
    }

    parts.append(commandTarget)
    return parts.joined(separator: " ")
  }

  private var filteredRuntimes: [UVPythonRuntime] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmedQuery.isEmpty else {
      return uvManager.pythonRuntimes
    }

    return uvManager.pythonRuntimes.filter { runtime in
      runtime.searchableText.contains(trimmedQuery)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      Form {
        targetPicker
        options
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)

      Divider()

      actionButtons
    }
    .frame(width: 680, height: 600)
    .background(Color(NSColor.windowBackgroundColor))
    .sheet(isPresented: $showTerminalOutput) {
      EnhancedTerminalView(processManager: uvManager.processManager) {
        dismiss()
      }
      .frame(width: 760, height: 520)
    }
    .task {
      if uvManager.pythonRuntimes.isEmpty {
        await uvManager.fetchPythonRuntimes()
      }

      if let initialRuntime, selectedRuntime == nil && query.isEmpty {
        select(initialRuntime)
      }
    }
    .onChange(of: query) { _, newValue in
      guard let selectedRuntime else { return }
      if newValue != selectedRuntime.target && newValue != selectedRuntime.displayName {
        self.selectedRuntime = nil
        upgradeExisting = false
        reinstallExisting = false
      }
    }
    .onChange(of: upgradeExisting) { _, newValue in
      if newValue {
        reinstallExisting = false
      }
    }
    .onChange(of: reinstallExisting) { _, newValue in
      if newValue {
        upgradeExisting = false
      }
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.down.circle")
        .font(.title3)
        .foregroundStyle(Color.accentColor)

      VStack(alignment: .leading, spacing: 2) {
        Text("Install Python")
          .font(.headline)

        Text("Select a runtime from uv python list or type a target.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var targetPicker: some View {
    Section("Python Target") {
      TextField("e.g., 3.13, cpython-3.13.13-macos-aarch64-none, pypy-3.11", text: $query)
        .textFieldStyle(.roundedBorder)
        .onSubmit {
          if selectedRuntime == nil, let firstMatch = filteredRuntimes.first {
            select(firstMatch)
          }
        }

      if !targetToInstall.isEmpty {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("Command")
            .font(.caption)
            .foregroundStyle(.secondary)

          Text(commandPreview)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
        }
      }

      suggestions
    }
  }

  private var suggestions: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Available Options")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Spacer()

          if uvManager.isPythonLoading {
            ProgressView()
              .controlSize(.small)
          }
        }

        if filteredRuntimes.isEmpty {
          Text(
            "No matching runtime from uv python list. The typed target can still be passed to uv."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
        } else {
          LazyVStack(spacing: 6) {
            ForEach(Array(filteredRuntimes.prefix(40))) { runtime in
              Button {
                select(runtime)
              } label: {
                PythonRuntimeSuggestionRow(
                  runtime: runtime,
                  isSelected: selectedRuntime?.id == runtime.id
                )
              }
              .buttonStyle(.plain)
            }
          }

          if filteredRuntimes.count > 40 {
            Text("Showing first 40 matches")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var options: some View {
    Section("Options") {
      Toggle("Use as default Python", isOn: $setAsDefault)

      Toggle("Upgrade selected installed minor version to latest patch", isOn: $upgradeExisting)
        .disabled(!canUpgradeExisting)

      Toggle("Reinstall selected installed runtime", isOn: $reinstallExisting)
        .disabled(!canReinstallExisting)

      if selectedRuntime != nil && !canUpgradeExisting && !canReinstallExisting {
        Text(
          "Install downloadable runtimes directly. Upgrade and reinstall actions apply to uv-managed installed runtimes."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
        Toggle("Compile standard library bytecode after installation", isOn: $compileBytecode)
          .padding(.top, 8)
      }
    }
  }

  private var actionButtons: some View {
    HStack {
      Button("Cancel") {
        dismiss()
      }
      .keyboardShortcut(.escape)

      Spacer()

      Button {
        showTerminalOutput = true
        install()
      } label: {
        Label(primaryActionTitle, systemImage: "arrow.down.circle")
      }
      .keyboardShortcut(.return)
      .buttonStyle(.borderedProminent)
      .disabled(commandTarget.isEmpty || isInstalling)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var primaryActionTitle: String {
    if canUpgradeExisting && upgradeExisting {
      return "Upgrade"
    }

    if canReinstallExisting && reinstallExisting {
      return "Reinstall"
    }

    return "Install"
  }

  private func select(_ runtime: UVPythonRuntime) {
    selectedRuntime = runtime
    query = runtime.target

    if !runtime.isUvManaged {
      upgradeExisting = false
      reinstallExisting = false
    }
  }

  private func install() {
    let target = commandTarget
    guard !target.isEmpty else { return }

    isInstalling = true

    Task {
      do {
        try await uvManager.installPython(
          target: target,
          setAsDefault: setAsDefault,
          upgrade: canUpgradeExisting && upgradeExisting,
          reinstall: canReinstallExisting && reinstallExisting,
          compileBytecode: compileBytecode
        )
      } catch {
        await MainActor.run {
          uvManager.lastError = error.localizedDescription
        }
      }

      await MainActor.run {
        isInstalling = false
      }
    }
  }
}

private struct PythonRuntimeSuggestionRow: View {
  let runtime: UVPythonRuntime
  let isSelected: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(isSelected ? .blue : .secondary)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(runtime.displayName)
            .font(.headline)

          if runtime.isInstalled {
            StatusBadge(text: runtime.installSourceLabel, color: runtime.installSourceBadgeColor)
          }

          if runtime.isFreethreaded {
            StatusBadge(text: "Free-threaded", color: .purple)
          }
        }

        Text(runtime.target)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)

        if let location = runtime.installedLocations.first {
          Text(location)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }

      Spacer()
    }
    .padding(8)
    .background(
      isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    .contentShape(Rectangle())
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
