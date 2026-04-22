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
    }

    private var systemRuntimes: [UVPythonRuntime] {
        filtered(uvManager.pythonRuntimes.filter { $0.isInstalled && $0.isFrameworkPython })
    }

    private var downloadableRuntimes: [UVPythonRuntime] {
        filtered(uvManager.pythonRuntimes.filter { $0.isDownloadAvailable && !$0.isInstalled })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if uvManager.isPythonLoading && uvManager.pythonRuntimes.isEmpty {
                ProgressView("Loading Python versions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        runtimeSection(
                            title: "System Python",
                            runtimes: systemRuntimes,
                            emptyMessage: searchText.isEmpty ? "No framework Python installs found." : "No matching framework Python installs.",
                            footer: "These Python installs are outside uv's managed runtime directory and should not be managed by uv."
                        )

                        runtimeSection(
                            title: "Installed",
                            runtimes: installedRuntimes,
                            emptyMessage: "No uv-managed Python versions found."
                        )

                        runtimeSection(
                            title: "Available to Download",
                            runtimes: downloadableRuntimes,
                            emptyMessage: searchText.isEmpty ? "No downloadable Python versions found." : "No matching downloadable Python versions.",
                            onInstall: { runtime in
                                runtimeToInstall = runtime
                                showInstallSheet = true
                            }
                        )
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Python Versions")
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
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                guard let runtime = runtimeToUninstall else { return }
                showTerminalOutput = true
                Task {
                    do {
                        try await uvManager.uninstallPython(target: runtime.target)
                    } catch {
                        await MainActor.run {
                            uvManager.lastError = error.localizedDescription
                        }
                    }
                }
            }
        } message: {
            if let runtime = runtimeToUninstall {
                Text("Uninstall \(runtime.displayName)? This removes the uv-managed Python runtime for \(runtime.target).")
            }
        }
        .task {
            if uvManager.pythonRuntimes.isEmpty {
                await uvManager.fetchPythonRuntimes()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                PythonLogoIcon(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Python Versions")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("uv python list")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await uvManager.fetchPythonRuntimes()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(uvManager.isPythonLoading)

            }

            TextField("Filter by version, implementation, target, or path", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 480)
        }
        .padding()
    }

    private func runtimeSection(
        title: String,
        runtimes: [UVPythonRuntime],
        emptyMessage: String,
        footer: String? = nil,
        onInstall: ((UVPythonRuntime) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)

                Text("\(runtimes.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            if runtimes.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(runtimes) { runtime in
                        PythonRuntimeRow(runtime: runtime) {
                            runtimeToUninstall = runtime
                        } onInstall: {
                            onInstall?(runtime)
                        }
                    }
                }
            }

            if let footer, !runtimes.isEmpty {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: runtime.isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(runtime.isInstalled ? .green : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(runtime.displayName)
                        .font(.headline)

                    PythonRuntimeBadge(text: runtime.implementationDisplayName, color: .blue)

                    if runtime.isFreethreaded {
                        PythonRuntimeBadge(text: "Free-threaded", color: .purple)
                    }

                    if runtime.isEndOfLife {
                        Link(destination: URL(string: "https://devguide.python.org/versions/")!) {
                            PythonRuntimeBadge(text: "End-of-Life", color: .red)
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

            VStack(alignment: .trailing, spacing: 6) {
                if runtime.isInstalled {
                    PythonRuntimeBadge(text: runtime.installSourceLabel, color: runtime.installSourceBadgeColor)
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
                    .help("Uninstall \(runtime.displayName)")
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
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func locationSummary(_ location: String) -> String {
        if let aliasTarget = runtime.installedEntries.first(where: { $0.location == location })?.aliasTarget {
            return "\(runtime.installedEntries.first(where: { $0.location == location })?.executablePath ?? location) -> \(aliasTarget)"
        }
        return location
    }
}

private struct PythonRuntimeBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private extension UVPythonRuntime {
    var installSourceBadgeColor: Color {
        if isUvManaged {
            return .green
        }

        if isFrameworkPython {
            return .blue
        }

        return .orange
    }
}
