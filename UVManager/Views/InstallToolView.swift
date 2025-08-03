import SwiftUI

struct InstallToolView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var uvManager: UVManager
    @StateObject private var processManager = ProcessManager()
    
    @State private var packageName = ""
    @State private var additionalPackages: [String] = []
    @State private var newPackage = ""
    @State private var forceInstall = false
    @State private var isInstalling = false
    @State private var showTerminalOutput = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    packageSection
                    additionalPackagesSection
                    optionsSection
                }
                .padding()
            }
            
            Divider()
            
            actionButtons
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showTerminalOutput) {
            TerminalOutputView(processManager: processManager)
                .frame(width: 700, height: 500)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            
            Text("Install Python Tool")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Install a tool from PyPI with optional dependencies")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var packageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Package Name", systemImage: "shippingbox")
                .font(.headline)
            
            HStack {
                TextField("e.g., ruff, black, pytest", text: $packageName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Package name")
                    .accessibilityHint("Enter the exact package name as it appears on PyPI")
                
                if !packageName.isEmpty {
                    Link(destination: URL(string: "https://pypi.org/project/\(packageName)/")!) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .help("View on PyPI")
                    .accessibilityLabel("View \(packageName) on PyPI")
                }
            }
            
            Text("Enter the exact package name as it appears on PyPI")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var additionalPackagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Additional Packages (Optional)", systemImage: "link")
                .font(.headline)
            
            HStack {
                TextField("e.g., pandas, numpy", text: $newPackage)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addPackage()
                    }
                    .accessibilityLabel("Additional package name")
                    .accessibilityHint("Press return to add package to the list")
                
                Button("Add", action: addPackage)
                    .disabled(newPackage.isEmpty)
            }
            
            if !additionalPackages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(additionalPackages, id: \.self) { package in
                            HStack(spacing: 4) {
                                Text(package)
                                    .font(.caption)
                                
                                Button {
                                    additionalPackages.removeAll { $0 == package }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
            
            Text("These packages will be installed in the same virtual environment")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Options", systemImage: "gearshape")
                .font(.headline)
            
            Toggle(isOn: $forceInstall) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Force Install")
                    Text("Reinstall the tool even if it already exists")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Force install")
            .accessibilityHint("When enabled, reinstalls the tool even if it already exists")
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
                Label("Install", systemImage: "arrow.down.circle")
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .disabled(packageName.isEmpty || isInstalling)
        }
        .padding()
    }
    
    private func addPackage() {
        let trimmed = newPackage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !additionalPackages.contains(trimmed) {
            additionalPackages.append(trimmed)
            newPackage = ""
        }
    }
    
    private func install() {
        isInstalling = true
        
        Task {
            do {
                try await uvManager.installTool(
                    name: packageName,
                    withPackages: additionalPackages,
                    force: forceInstall
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Installation failed: \(error)")
            }
            
            await MainActor.run {
                isInstalling = false
            }
        }
    }
}