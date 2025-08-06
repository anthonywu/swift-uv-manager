import SwiftUI
import SwiftTerm

struct EnhancedTerminalView: View {
    @ObservedObject var processManager: ProcessManager
    @EnvironmentObject var uvManager: UVManager
    @Environment(\.dismiss) private var dismiss
    @State private var commandDisplay: String = ""
    @FocusState private var isTerminalFocused: Bool
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Terminal", systemImage: "terminal.fill")
                    .font(.headline)
                
                if !commandDisplay.isEmpty {
                    Text("$ \(commandDisplay)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                if processManager.isRunning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
                
                Button {
                    onDismiss?()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Terminal view only
            SwiftTermView(processManager: processManager)
                .background(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Footer with controls
            Divider()
            
            HStack {
                if processManager.isRunning {
                    Text("Process is running...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Process completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if processManager.isRunning {
                    Button("Cancel") {
                        processManager.cancel()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Close") {
                        onDismiss?()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
        .focused($isTerminalFocused)
        .onAppear {
            updateCommandDisplay()
            // Focus the terminal view when it appears
            isTerminalFocused = true
        }
        .onChange(of: processManager.pendingCommand) { _, _ in
            updateCommandDisplay()
        }
        .onKeyPress(.escape) {
            if !processManager.isRunning {
                onDismiss?()
                dismiss()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if !processManager.isRunning {
                onDismiss?()
                dismiss()
                return .handled
            }
            return .ignored
        }
        .onDisappear {
            // Refresh tools and UV installations when terminal is closed
            Task {
                // Check if this was a self-update command
                if let cmd = processManager.lastCommand,
                   cmd.arguments.contains("self") && cmd.arguments.contains("update") {
                    // Refresh UV installations after self-update
                    await uvManager.detectUVInstallations()
                    await uvManager.fetchToolsDirectory()
                }
                await uvManager.fetchTools()
            }
            onDismiss?()
        }
    }
    
    private func updateCommandDisplay() {
        if let cmd = processManager.pendingCommand {
            commandDisplay = "\(cmd.path) \(cmd.arguments.joined(separator: " "))"
        } else if let lastCmd = processManager.lastCommand {
            commandDisplay = "\(lastCmd.path) \(lastCmd.arguments.joined(separator: " "))"
        }
    }
}

