import SwiftUI

struct ToolDetailView: View {
    let tool: UVTool
    @EnvironmentObject var uvManager: UVManager
    @State private var showUpgradeAlert = false
    @State private var showUninstallAlert = false
    @State private var isPerformingAction = false
    
    // Computed property to get the current tool data
    private var currentTool: UVTool? {
        uvManager.tools.first { $0.name == tool.name }
    }
    
    var body: some View {
        Group {
            if let currentTool = currentTool {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        
                        if !currentTool.executables.isEmpty {
                            executablesSection
                        }
                        
                        if !currentTool.withPackages.isEmpty || !currentTool.extras.isEmpty {
                            dependenciesSection
                        }
                        
                        actionsSection
                    }
                    .padding()
                }
                .navigationTitle(currentTool.name)
                .navigationSubtitle("v\(currentTool.version)")
            } else {
                // Tool was uninstalled
                EmptyStateView()
            }
        }
        .alert("Upgrade Tool", isPresented: $showUpgradeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Upgrade") {
                Task {
                    isPerformingAction = true
                    do {
                        try await uvManager.upgradeTool(name: currentTool?.name ?? tool.name)
                    } catch {
                        print("Upgrade failed: \(error)")
                    }
                    isPerformingAction = false
                }
            }
        } message: {
            Text("Are you sure you want to upgrade \(currentTool?.name ?? tool.name)? This will update to the latest version available on PyPI.")
        }
        .alert("Uninstall Tool", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task {
                    isPerformingAction = true
                    do {
                        try await uvManager.uninstallTool(name: currentTool?.name ?? tool.name)
                    } catch {
                        print("Uninstall failed: \(error)")
                    }
                    isPerformingAction = false
                }
            }
        } message: {
            Text("Are you sure you want to uninstall \(currentTool?.name ?? tool.name)? This will remove all executables and the tool's virtual environment.")
        }
    }
    
    private var headerSection: some View {
        guard let currentTool = currentTool else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(currentTool.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version \(currentTool.version)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if let url = currentTool.pypiURL {
                        Link(destination: url) {
                            Label("View on PyPI", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                if let specifier = currentTool.versionSpecifier {
                    Label {
                        Text(specifier)
                            .font(.callout)
                    } icon: {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.orange)
                    }
                }
                
                Label {
                    Text(currentTool.path)
                        .font(.caption)
                        .textSelection(.enabled)
                } icon: {
                    Image(systemName: "folder")
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        )
    }
    
    private var executablesSection: some View {
        guard let currentTool = currentTool else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Label("Executables", systemImage: "terminal")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(currentTool.executables) { executable in
                        HStack {
                            Text(executable.name)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(executable.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .background(.tertiary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        )
    }
    
    private var dependenciesSection: some View {
        guard let currentTool = currentTool else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Label("Dependencies & Extras", systemImage: "link")
                    .font(.headline)
                
                if !currentTool.withPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional Packages")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(currentTool.withPackages, id: \.self) { package in
                                Text(package)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.green.opacity(0.2), in: Capsule())
                            }
                        }
                    }
                }
                
                if !currentTool.extras.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extras")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(currentTool.extras, id: \.self) { extra in
                                Text(extra)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.2), in: Capsule())
                            }
                        }
                    }
                }
            }
        )
    }
    
    private var actionsSection: some View {
        HStack(spacing: 16) {
            Button {
                showUpgradeAlert = true
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isPerformingAction)
            
            Button {
                showUninstallAlert = true
            } label: {
                Label("Uninstall", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .disabled(isPerformingAction)
        }
        .padding(.top)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.frames[index].origin.x + bounds.minX,
                                     y: result.frames[index].origin.y + bounds.minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var height: CGFloat = 0
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            height = currentY + lineHeight
        }
    }
}