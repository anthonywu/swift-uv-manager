# Agents Guidelines

## Project Overview

**UV Manager** is a native macOS GUI app for managing Python tools and runtimes via [uv](https://github.com/astral-sh/uv). It is built with Swift 5.9, SwiftUI, and targets macOS 14+.

- **Bundle ID**: `com.anthonywu.uvmanager`
- **Repository**: https://github.com/anthonywu/swift-uv-manager
- **Dependency**: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (embedded terminal)

## Project Structure

```
UVManager/
├── UVManagerApp.swift        # @main app entry point
├── Constants.swift           # AppConstants enum
├── Models/
│   ├── UVTool.swift          # UVTool, UVInstallation models
│   └── UVPythonRuntime.swift # UVPythonRuntime model + parsing
├── Services/
│   ├── UVManager.swift       # @MainActor ObservableObject — core business logic
│   └── ProcessManager.swift  # Shell command execution
├── Views/                    # SwiftUI views (ContentView, PythonManagerView, etc.)
├── Assets.xcassets/
└── Resources/
```

- `Info.plist` — at the repo root, used by `build_release.sh` to read version info
- `Package.swift` — Swift Package Manager manifest (executable target, not a library)
- `justfile` — dev/release task runner (`just dev`, `just release`, `just release-draft`)
- `build_release.sh` — full release pipeline: build → sign → notarize → DMG

## Coding Conventions

- **UI framework**: SwiftUI with `NavigationSplitView`, `@EnvironmentObject` for dependency injection
- **Architecture**: Single `UVManager` ObservableObject (marked `@MainActor`) injected via `.environmentObject()` into the view hierarchy
- **Models**: Plain structs conforming to `Identifiable, Hashable`; parsing logic lives as static methods on the model (e.g., `UVPythonRuntime.parseList`)
- **Constants**: Use `AppConstants` enum (caseless) for app-wide constants
- **Error handling**: Custom errors as enums conforming to `LocalizedError`
- **Concurrency**: Swift `async/await` with `Task {}` blocks; no Combine pipelines beyond `@Published`
- **String extensions**: Private extensions in the file that needs them (e.g., `strippingANSI()`, `expandedHomePath`)
- **No tests**: The project currently has no test targets

## Versioning

- Version is set in `Info.plist` (`CFBundleShortVersionString`)
- `Constants.swift` reads version from the bundle at runtime
- `build_release.sh` reads version from `Info.plist` via `PlistBuddy`
- When bumping versions, update `Info.plist` — that is the single source of truth

## Build & Run

- **Dev**: `just dev` (or `swift build && swift run UVManager`)
- **Format**: `just format` (runs `swift-format` in-place on `UVManager/`)
- **Lint**: `just lint` (runs `swiftlint` on `UVManager/`)
- **Release**: `just release` (runs `build_release.sh`, requires code signing credentials)
- **Draft GitHub release**: `just release-draft version=X.Y.Z`

## GitHub Releases

Release titles must follow the established convention:

```
v{VERSION} – {summary of changes}
```

Use an en-dash (`–`) as the separator between the version tag and the summary. Examples:

- `v0.4.1 – fix: prevent uninstalling the active Python runtime from the Python Versions view`
- `v0.4.0 – uv python install and uninstall now managed in the app`
- `v0.3.0 – Apple Developer signing; Custom app icon, DMG distribution`
