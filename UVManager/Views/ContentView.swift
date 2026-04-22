import SwiftUI

enum SidebarDestination: Hashable {
    case python
    case tool(String)
}

struct ContentView: View {
    @EnvironmentObject var uvManager: UVManager
    @State private var selectedDestination: SidebarDestination?
    @State private var searchText = ""
    @State private var showInstallSheet = false
    @State private var showError = false
    @State private var showUpdateTerminal = false
    
    var filteredTools: [UVTool] {
        if searchText.isEmpty {
            return uvManager.tools
        }
        return uvManager.tools.filter { tool in
            tool.name.localizedCaseInsensitiveContains(searchText) ||
            tool.version.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var isRefreshingSelectedArea: Bool {
        selectedDestination == .python ? uvManager.isPythonLoading : uvManager.isLoading
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            if selectedDestination == .python {
                PythonManagerView()
            } else if case .tool(let toolName) = selectedDestination,
                      let tool = uvManager.tools.first(where: { $0.name == toolName }) {
                ToolDetailView(tool: tool)
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, placement: .sidebar)
        .sheet(isPresented: $showInstallSheet) {
            InstallToolView()
        }
        .sheet(isPresented: $showUpdateTerminal) {
            EnhancedTerminalView(processManager: uvManager.processManager)
                .frame(width: 700, height: 500)
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
                            await uvManager.fetchPythonRuntimes()
                        }
                    }
                } else if let installation = uvManager.selectedInstallation {
                    HStack(spacing: 8) {
                        Text("UV \(installation.version)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Button("Update uv") {
                            showUpdateTerminal = true
                            Task {
                                await uvManager.selfUpdate()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Button {
                    showInstallSheet = true
                } label: {
                    Text("Install New Tool")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task {
                        if selectedDestination == .python {
                            await uvManager.fetchPythonRuntimes()
                        } else {
                            await uvManager.fetchTools()
                        }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshingSelectedArea)
                .rotationEffect(.degrees(isRefreshingSelectedArea ? 360 : 0))
                .animation(isRefreshingSelectedArea ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshingSelectedArea)
            }
        }
    }
    
    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedDestination) {
                if uvManager.installations.isEmpty {
                    NoUVInstalledView()
                } else {
                    Section {
                        Label {
                            Text("Python Versions")
                        } icon: {
                            PythonLogoIcon()
                        }
                            .tag(SidebarDestination.python)
                    } header: {
                        Text("Runtime")
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
                    
                    Section {
                        ForEach(filteredTools) { tool in
                            ToolRowView(tool: tool)
                                .tag(SidebarDestination.tool(tool.name))
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
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Footer with version and GitHub attribution
            VStack(spacing: 8) {
                Text("\(AppConstants.appName) v\(AppConstants.version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Link("Project on GitHub", destination: URL(string: AppConstants.githubURL)!)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .navigationTitle("UV Manager")
        .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
    }
}

struct PythonLogoIcon: View {
    var width: CGFloat = 18
    var height: CGFloat = 18

    var body: some View {
        if let image = pythonLogoImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
        } else {
            Image(systemName: "curlybraces")
                .frame(width: width, height: height)
        }
    }

    private var pythonLogoImage: NSImage? {
        guard let url = Bundle.module.url(forResource: "python-logo", withExtension: "svg") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

struct EmptyStateView: View {
    @State private var showInstallSheet = false
    
    private let koans = [
        "The fastest resolver\nstill waits for the slowest mirror.",
        "In the virtual environment,\nwhich Python is real?",
        "Dependencies resolved,\nhuman conflicts remain.",
        "Empty requirements.txt,\ninfinite possibilities.",
        "One tool to rule them all,\nstill needs updating."
    ]
    
    @State private var selectedKoanIndex: Int = Int.random(in: 0..<5)
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)
            
            Text("Select a tool from the sidebar to view details")
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
            
            Spacer()
                .frame(height: 40)
            
            Divider()
                .frame(width: 300)
            
            // Zen Koan - Click to rotate
            Button(action: {
                selectedKoanIndex = (selectedKoanIndex + 1) % koans.count
            }) {
                VStack(spacing: 8) {
                    Text("\"\(koans[selectedKoanIndex])\"")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .italic()
                        .padding(.horizontal, 30)
                    
                    Text("— Zen of UV Manager —")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .help("Click to see next koan")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showInstallSheet) {
            InstallToolView()
        }
    }
}
