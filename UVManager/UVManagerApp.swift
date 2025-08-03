import SwiftUI

@main
struct UVManagerApp: App {
    @StateObject private var uvManager = UVManager()
    
    init() {
        // Ensure the app activates properly
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(uvManager)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // Ensure window is visible
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.center()
                        window.setIsVisible(true)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About UV Manager") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: AppConstants.appName,
                            .applicationIcon: NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: "UV Manager Icon") as Any,
                            .applicationVersion: AppConstants.version,
                            .credits: NSAttributedString(string: "A beautiful macOS interface for Python tool management via UV\n\n© 2025 Anthony Wu", attributes: [.font: NSFont.systemFont(ofSize: 11)])
                        ]
                    )
                }
            }
        }
    }
}