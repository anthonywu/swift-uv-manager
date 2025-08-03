import SwiftUI

struct ContentView: View {
    @EnvironmentObject var uvManager: UVManager
    @State private var selectedTool: UVTool?
    @State private var searchText = ""
    @State private var showInstallSheet = false
    @State private var showError = false
    
    var filteredTools: [UVTool] {
        if searchText.isEmpty {
            return uvManager.tools
        }
        return uvManager.tools.filter { tool in
            tool.name.localizedCaseInsensitiveContains(searchText) ||
            tool.version.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let tool = selectedTool {
                ToolDetailView(tool: tool)
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $searchText, placement: .sidebar)
        .sheet(isPresented: $showInstallSheet) {
            InstallToolView()
        }
        .alert("Error", isPresented: $showError, presenting: uvManager.lastError) { _ in
            Button("OK") { uvManager.lastError = nil }
        } message: { error in
            Text(error)
        }
        .onChange(of: uvManager.lastError) { oldValue, newValue in
            showError = newValue != nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if uvManager.installations.count > 1 {
                    Picker("UV Version", selection: $uvManager.selectedInstallation) {
                        ForEach(uvManager.installations) { installation in
                            Text(installation.displayName)
                                .tag(installation as UVInstallation?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: uvManager.selectedInstallation) { oldValue, newValue in
                        Task {
                            await uvManager.fetchToolsDirectory()
                            await uvManager.fetchTools()
                        }
                    }
                } else if let installation = uvManager.selectedInstallation {
                    Text("UV \(installation.version)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    showInstallSheet = true
                } label: {
                    Text("Install New Tool")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task {
                        await uvManager.fetchTools()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(uvManager.isLoading)
                .rotationEffect(.degrees(uvManager.isLoading ? 360 : 0))
                .animation(uvManager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: uvManager.isLoading)
            }
        }
    }
    
    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedTool) {
                if uvManager.installations.isEmpty {
                    NoUVInstalledView()
                } else {
                    Section {
                        ForEach(filteredTools) { tool in
                            ToolRowView(tool: tool)
                                .tag(tool)
                        }
                    } header: {
                        HStack {
                            Text("Installed Tools")
                            Spacer()
                            Text("\(filteredTools.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !filteredTools.isEmpty {
                        Section {
                            BulkActionsView()
                        }
                    }
                    
                    if !uvManager.toolsDirectory.isEmpty {
                        Section {
                            Label {
                                Text(uvManager.toolsDirectory)
                                    .font(.caption)
                                    .textSelection(.enabled)
                            } icon: {
                                Image(systemName: "folder")
                            }
                        } header: {
                            Text("Tools Directory")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Footer with GitHub attribution
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Created by")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("Anthony Wu", destination: URL(string: "https://github.com/anthonywu")!)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .navigationTitle("UV Manager")
        .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
    }
}

struct EmptyStateView: View {
    @State private var showInstallSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)
            
            Text("Select a tool to view details")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("or")
                .font(.callout)
                .foregroundStyle(.tertiary)
            
            Button("Install New Tool") {
                showInstallSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showInstallSheet) {
            InstallToolView()
        }
    }
}