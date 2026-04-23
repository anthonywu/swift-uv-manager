import SwiftTerm
import SwiftUI

struct EnhancedTerminalView: View {
  @ObservedObject var processManager: ProcessManager
  @EnvironmentObject var uvManager: UVManager
  @Environment(\.dismiss) private var dismiss
  @State private var commandDisplay: String = ""
  @FocusState private var isTerminalFocused: Bool
  var onDismiss: (() -> Void)?

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      SwiftTermView(processManager: processManager)
        .background(Color.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      footer
    }
    .frame(minWidth: 700, minHeight: 500)
    .focused($isTerminalFocused)
    .onAppear {
      updateCommandDisplay()
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
      Task {
        if let cmd = processManager.lastCommand,
          cmd.arguments.contains("self") && cmd.arguments.contains("update")
        {
          await uvManager.detectUVInstallations()
          await uvManager.fetchToolsDirectory()
        }
        await uvManager.fetchTools()
        await uvManager.fetchPythonRuntimes()
        await uvManager.fetchCacheInfo()
      }
      onDismiss?()
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Label("Command Output", systemImage: "terminal")
        .font(.headline)

      if !commandDisplay.isEmpty {
        Text(commandDisplay)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }

      Spacer()

      if processManager.isRunning {
        ProgressView()
          .controlSize(.small)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var footer: some View {
    HStack {
      Label(processManager.isRunning ? "Running" : "Completed", systemImage: statusImage)
        .font(.caption)
        .foregroundStyle(.secondary)

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
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var statusImage: String {
    processManager.isRunning ? "hourglass" : "checkmark.circle"
  }

  private func updateCommandDisplay() {
    if let cmd = processManager.pendingCommand {
      commandDisplay = "\(cmd.path) \(cmd.arguments.joined(separator: " "))"
    } else if let lastCmd = processManager.lastCommand {
      commandDisplay = "\(lastCmd.path) \(lastCmd.arguments.joined(separator: " "))"
    }
  }
}
