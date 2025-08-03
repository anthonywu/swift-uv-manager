import SwiftUI

struct TerminalOutputView: View {
    @ObservedObject var processManager: ProcessManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Terminal Output", systemImage: "terminal")
                    .font(.headline)
                
                Spacer()
                
                if processManager.isRunning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if processManager.output.isEmpty && processManager.error.isEmpty {
                            if processManager.isRunning {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                    Text("Waiting for output...")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.gray)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                            } else {
                                Text("No output")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            }
                        }
                        
                        if !processManager.output.isEmpty {
                            Text(processManager.output)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
                .foregroundStyle(Color(NSColor.labelColor))
                .onChange(of: processManager.output) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: processManager.error) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            if processManager.isRunning {
                Divider()
                
                HStack {
                    Text("Process is running...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        processManager.cancel()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}