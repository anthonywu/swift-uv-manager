import SwiftUI

struct SystemInfoView: View {
    @EnvironmentObject var uvManager: UVManager
    @State private var showPruneAlert = false
    @State private var showTerminalOutput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewSection
                    maintenanceSection
                }
                .padding()
            }
        }
        .navigationTitle("UV System Info")
        .task {
            if uvManager.toolsDirectory.isEmpty || uvManager.cacheDirectory.isEmpty || uvManager.cacheSizeBytes == nil {
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
            Button("Cancel", role: .cancel) { }
            Button("Prune", role: .destructive) {
                pruneCache()
            }
        } message: {
            Text("Remove all unreachable objects from the uv cache? Objects still referenced by uv are kept.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.blue)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("UV System Info")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("uv tool dir · uv cache")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await fetchSystemInfo()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(uvManager.isCacheLoading)
            }
        }
        .padding()
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Directories", systemImage: "folder")
                .font(.headline)

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
        .padding()
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            Text("Prune removes unreachable cache objects and keeps cache entries still referenced by uv.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button(role: .destructive) {
                    showPruneAlert = true
                } label: {
                    Label("Prune Cache", systemImage: "trash")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(uvManager.selectedInstallation == nil || uvManager.processManager.isRunning)

                Spacer()

                if uvManager.isCacheLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
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
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

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
        .padding(10)
        .background(.tertiary.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
    }

    private var isDirectoryRow: Bool {
        title.localizedCaseInsensitiveContains("Directory")
    }
}
