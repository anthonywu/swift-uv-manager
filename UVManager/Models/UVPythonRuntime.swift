import Foundation

struct UVPythonRuntime: Identifiable, Hashable {
    let target: String
    let implementation: String
    let version: String
    let platform: String
    let isFreethreaded: Bool
    var entries: [Entry]

    var id: String { target }

    var displayName: String {
        let suffix = isFreethreaded ? " free-threaded" : ""
        return "\(implementationDisplayName) \(version)\(suffix)"
    }

    var implementationDisplayName: String {
        switch implementation.lowercased() {
        case "cpython":
            return "CPython"
        case "pypy":
            return "PyPy"
        case "graalpy":
            return "GraalPy"
        default:
            return implementation.capitalized
        }
    }

    var isDownloadAvailable: Bool {
        entries.contains { $0.isDownloadAvailable }
    }

    var installedEntries: [Entry] {
        entries.filter { !$0.isDownloadAvailable }
    }

    var installedLocations: [String] {
        installedEntries.map(\.location)
    }

    var isInstalled: Bool {
        !installedEntries.isEmpty
    }

    var isUvManaged: Bool {
        installedLocations.contains { $0.contains("/.local/share/uv/python/") }
    }

    var isFrameworkPython: Bool {
        installedLocations.contains { $0.contains("/Library/Frameworks/Python.framework/") }
    }

    var installSourceLabel: String {
        if isUvManaged {
            return "uv-managed"
        }

        if isFrameworkPython {
            return "System Python"
        }

        return "External"
    }

    var searchableText: String {
        ([target, implementation, version, displayName, platform] + installedLocations)
            .joined(separator: " ")
            .lowercased()
    }

    var minorVersion: String? {
        let components = version.split(separator: ".")
        guard components.count >= 2 else { return nil }
        return "\(components[0]).\(components[1])"
    }

    var upgradeTarget: String? {
        guard let minorVersion else { return nil }

        switch implementation.lowercased() {
        case "cpython":
            return isFreethreaded ? "\(minorVersion)t" : minorVersion
        default:
            return "\(implementation.lowercased())@\(minorVersion)"
        }
    }

    var isEndOfLife: Bool {
        let components = version.split(separator: ".")
        guard components.count >= 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return false
        }

        return major < 3 || (major == 3 && minor <= 9)
    }

    struct Entry: Identifiable, Hashable {
        let id = UUID()
        let location: String

        var isDownloadAvailable: Bool {
            location == "<download available>"
        }

        var executablePath: String {
            location.components(separatedBy: " -> ").first ?? location
        }

        var aliasTarget: String? {
            let parts = location.components(separatedBy: " -> ")
            guard parts.count > 1 else { return nil }
            return parts.dropFirst().joined(separator: " -> ")
        }
    }

    static func parseList(_ output: String) -> [UVPythonRuntime] {
        var runtimesByTarget: [String: UVPythonRuntime] = [:]
        var targetOrder: [String] = []

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.strippingANSI().trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty,
                  !line.hasPrefix("warning:"),
                  !line.hasPrefix("hint:") else {
                continue
            }

            let parts = line.split(maxSplits: 1, omittingEmptySubsequences: true) { $0.isWhitespace }
            guard let targetPart = parts.first, parts.count > 1 else { continue }

            let target = String(targetPart)
            let location = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let metadata = parseTarget(target) else { continue }

            if runtimesByTarget[target] == nil {
                runtimesByTarget[target] = UVPythonRuntime(
                    target: target,
                    implementation: metadata.implementation,
                    version: metadata.version,
                    platform: metadata.platform,
                    isFreethreaded: metadata.isFreethreaded,
                    entries: []
                )
                targetOrder.append(target)
            }

            runtimesByTarget[target]?.entries.append(Entry(location: location))
        }

        return targetOrder.compactMap { runtimesByTarget[$0] }
    }

    private static func parseTarget(_ target: String) -> (implementation: String, version: String, platform: String, isFreethreaded: Bool)? {
        let components = target.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count >= 3 else { return nil }

        let implementation = String(components[0])
        let versionToken = String(components[1])
        let version = versionToken.components(separatedBy: "+").first ?? versionToken
        let isFreethreaded = versionToken.contains("+freethreaded")
        let platform = components.dropFirst(2).joined(separator: "-")

        return (implementation, version, platform, isFreethreaded)
    }
}

private extension String {
    func strippingANSI() -> String {
        let pattern = "\u{001B}\\[[0-?]*[ -/]*[@-~]"
        return replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
