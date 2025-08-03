#!/usr/bin/env swift

import SwiftUI
import AppKit

// Simple preview app to run the UV Manager without full compilation
@main
struct PreviewApp: App {
    var body: some Scene {
        WindowGroup {
            Text("UV Manager")
                .font(.largeTitle)
                .padding()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

// Run the preview
NSApplication.shared.run()