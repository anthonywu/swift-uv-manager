import SwiftUI
import SwiftTerm

struct SwiftTermView: NSViewRepresentable {
    @ObservedObject var processManager: ProcessManager
    
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: SwiftTermView
        
        init(_ parent: SwiftTermView) {
            self.parent = parent
        }
        
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Handle size changes if needed
        }
        
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Handle title changes if needed
        }
        
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Handle directory updates if needed
        }
        
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            Task { @MainActor in
                self.parent.processManager.isRunning = false
                
                // Add a completion message to the terminal
                let message = if let code = exitCode {
                    if code == 0 {
                        "\n\n✅ Process completed successfully. You can close this window.\n"
                    } else {
                        "\n\n❌ Process exited with code \(code). You can close this window.\n"
                    }
                } else {
                    "\n\n⚠️ Process terminated. You can close this window.\n"
                }
                
                // Inject the message into the terminal
                if let terminalView = source as? LocalProcessTerminalView {
                    terminalView.getTerminal().feed(text: message)
                }
                
                // Don't close the terminal view - let the user do it manually
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: NSRect.zero)
        terminalView.processDelegate = context.coordinator
        terminalView.autoresizingMask = [.width, .height]
        
        // Configure terminal appearance
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // Set up the terminal with monochrome colors only (white on black)
        let terminal = terminalView.getTerminal()
        terminal.backgroundColor = SwiftTerm.Color(red: 0, green: 0, blue: 0)
        terminal.foregroundColor = SwiftTerm.Color(red: 255, green: 255, blue: 255)
        
        // Configure the terminal view to use monochrome
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .white
        
        return terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // This is where we can start a new process when needed
        if let pendingCommand = processManager.pendingCommand {
            // Start the process in the terminal
            let args = pendingCommand.arguments
            let path = pendingCommand.path
            
            // Clear the pending command
            processManager.pendingCommand = nil
            
            // Start the process
            // Convert environment dictionary to array format required by SwiftTerm
            let envArray = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            nsView.startProcess(executable: path, args: args, environment: envArray, execName: path)
            
            Task { @MainActor in
                processManager.isRunning = true
            }
        }
    }
}

