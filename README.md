# UV Manager

A macOS app that provides a beautiful SwiftUI interface for managing Python tools via Astral's excellent `uv` tool.

## Status

Alpha release. It should mostly work and do no harm, however the community is invited to co-test this with me. Please file issues in the official repo

I will post `UVManager.app` via GitHub releases, but until I register with Apple Developers Program (todo), you will need to override the Gatekeeper warning by `sudo xattr -rd com.apple.quarantine ~/Downloads/UVManager.app` (adjust path arg if you download to somewhere else)

## Why UV Manager Exists

The Python ecosystem has created incredibly powerful command-line tools, but there's a CLI barrier between these tools and the many users who could benefit from them.

**The Problem**: Python users—data analysts, data scientists, business users, and hobbyists—need Python tools but lack the software engineering background to comfortably navigate command-line interfaces, virtual environments, and package management. They shouldn't need to understand the intricacies of `pip`, `venv`, or `PATH` configurations just to use a CLI or script that they received from a teammate.

**The Solution**: UV Manager bridges this gap by providing a native macOS interface that makes Python tool management as simple as using any other Mac application. No terminal commands, no environment confusion, no cryptic error messages—just click to install, upgrade, or remove the Python tools you need.

## Who This Helps

- **Data Analysts & Scientists** who want to use tools like Jupyter, pandas utilities, or data converters without wrestling with package conflicts
- **Business Users** who need Python-based reporting or automation tools but aren't comfortable with terminal commands  
- **Educators & Students** learning Python who can focus on using tools rather than managing installations
- **Casual Hobbyists** exploring Python tools for personal projects without the overhead of learning package management
- **Mac Users** who expect the polish and simplicity of native applications, not command-line interfaces

By wrapping the powerful UV package manager in an intuitive GUI, UV Manager expands inclusivity users beyond software engineers, making thousands of command-line tools accessible to users who would otherwise never discover or use them.

## Features

- **UV Detection & Management**: Automatically detects UV installations and allows version selection
- **Tool Management**: Install, upgrade, and uninstall Python tools with a native macOS interface
- **Live Terminal Output**: See real-time command execution with syntax highlighting
- **Bulk Operations**: Upgrade all tools at once with safety warnings
- **PyPI Integration**: Quick links to view packages on PyPI
- **Accessibility**: Full VoiceOver support and keyboard navigation
- **Apple HIG Compliance**: Native macOS design with smooth animations

## Requirements

- macOS 14.0 or later
- UV command-line tool (app will offer to install if missing) - pending verification this works

## Building

1. Open `UVManager.xcodeproj` in Xcode
2. Select your development team in project settings
3. Build and run (⌘R)

## Architecture

- **SwiftUI + MVVM**: Modern declarative UI with observable view models
- **Process/NSTask**: Safe execution of UV commands
- **Async/await**: Clean asynchronous operations
- **Combine**: Reactive data flow

## Target Audience

Software engineering adjacent Python users who may not understand software packaging:
- Data Analysts
- Data Scientists
- Business Users
- Casual hobbyists

The goal is to make Python tools accessible to a broader audience than software engineers and Python developers.

## License

MIT
