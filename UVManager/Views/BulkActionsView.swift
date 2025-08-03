import SwiftUI

struct BulkActionsView: View {
    @EnvironmentObject var uvManager: UVManager
    @State private var showUpgradeAllAlert = false
    @State private var isPerformingAction = false
    @State private var showTerminalOutput = false
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                showUpgradeAllAlert = true
            } label: {
                Label("Upgrade All Tools", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(uvManager.tools.isEmpty || isPerformingAction)
            
            Spacer()
            
            if isPerformingAction {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .alert("Upgrade All Tools", isPresented: $showUpgradeAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Upgrade All", role: .destructive) {
                showTerminalOutput = true
                upgradeAll()
            }
        } message: {
            Text("Are you sure you want to upgrade all \(uvManager.tools.count) tools? This may take several minutes and could potentially introduce breaking changes.")
        }
        .sheet(isPresented: $showTerminalOutput) {
            TerminalOutputView(processManager: uvManager.processManager)
                .frame(width: 700, height: 500)
        }
    }
    
    private func upgradeAll() {
        isPerformingAction = true
        
        Task {
            do {
                try await uvManager.upgradeAllTools()
            } catch {
                print("Upgrade all failed: \(error)")
            }
            
            await MainActor.run {
                isPerformingAction = false
            }
        }
    }
}