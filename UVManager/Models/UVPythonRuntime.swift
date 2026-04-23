import Foundation

struct UVPythonRuntime: Identifiable, Hashable {
  let target: String
  let implementation: String
  let version: String
  let platform: String
  let isFreethreaded: Bool
  let managedInstallDirectory: String?
  let defaultInterpreterPath: String?
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

  var isActive: Bool {
    guard let defaultInterpreterPath else { return false }
    return installedEntries.contains { entry in
      entry.executablePath.isSameFileSystemPath(as: defaultInterpreterPath)
    }
  }

  var isDefault: Bool {
    isActive
  }

  var isUvManaged: Bool {
    guard let managedInstallDirectory else { return false }
    return installedLocations.contains { location in
      location.expandedHomePath.hasPathPrefix(managedInstallDirectory)
    }
  }

  var isFrameworkPython: Bool {
    installedLocations.contains { $0.contains("/Library/Frameworks/Python.framework/") }
  }

  var isSystemPython: Bool {
    isFrameworkPython
      || installedLocations.contains { location in
        location.expandedHomePath == "/usr/bin/python3"
      }
  }

  var installSourceLabel: String {
    if isUvManaged {
      return "uv-managed"
    }

    if isSystemPython {
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

  func matchesUninstallTarget(_ requestedTarget: String) -> Bool {
    let normalizedTarget = requestedTarget.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    var candidates = [target, version]

    if let minorVersion {
      candidates.append(minorVersion)
      candidates.append("\(implementation.lowercased())@\(minorVersion)")
    }

    if let upgradeTarget {
      candidates.append(upgradeTarget)
    }

    return candidates.contains { $0.lowercased() == normalizedTarget }
  }

  var isEndOfLife: Bool {
    let components = version.split(separator: ".")
    guard components.count >= 2,
      let major = Int(components[0]),
      let minor = Int(components[1])
    else {
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

  static func parseList(
    _ output: String,
    managedInstallDirectory: String? = nil,
    defaultInterpreterPath: String? = nil
  ) -> [UVPythonRuntime] {
    var runtimesByTarget: [String: UVPythonRuntime] = [:]
    var targetOrder: [String] = []
    let normalizedManagedInstallDirectory = managedInstallDirectory?.expandedHomePath
      .trimmingTrailingSlashes()
    let normalizedDefaultInterpreterPath = defaultInterpreterPath?.expandedHomePath

    for rawLine in output.components(separatedBy: .newlines) {
      let line = rawLine.strippingANSI().trimmingCharacters(in: .whitespacesAndNewlines)

      guard !line.isEmpty,
        !line.hasPrefix("warning:"),
        !line.hasPrefix("hint:")
      else {
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
          managedInstallDirectory: normalizedManagedInstallDirectory,
          defaultInterpreterPath: normalizedDefaultInterpreterPath,
          entries: []
        )
        targetOrder.append(target)
      }

      runtimesByTarget[target]?.entries.append(Entry(location: location))
    }

    return targetOrder.compactMap { runtimesByTarget[$0] }
  }

  private static func parseTarget(_ target: String) -> (
    implementation: String, version: String, platform: String, isFreethreaded: Bool
  )? {
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

extension String {
  fileprivate func strippingANSI() -> String {
    let pattern = "\u{001B}\\[[0-?]*[ -/]*[@-~]"
    return replacingOccurrences(of: pattern, with: "", options: .regularExpression)
  }

  fileprivate var expandedHomePath: String {
    NSString(string: self).expandingTildeInPath.trimmingTrailingSlashes()
  }

  fileprivate func trimmingTrailingSlashes() -> String {
    var result = self
    while result.count > 1 && result.hasSuffix("/") {
      result.removeLast()
    }
    return result
  }

  fileprivate func hasPathPrefix(_ prefix: String) -> Bool {
    let normalizedSelf = expandedHomePath
    let normalizedPrefix = prefix.expandedHomePath
    return normalizedSelf == normalizedPrefix || normalizedSelf.hasPrefix(normalizedPrefix + "/")
  }

  fileprivate var resolvedFileSystemPath: String {
    URL(fileURLWithPath: expandedHomePath)
      .resolvingSymlinksInPath()
      .path
      .trimmingTrailingSlashes()
  }

  fileprivate func isSameFileSystemPath(as otherPath: String) -> Bool {
    resolvedFileSystemPath == otherPath.resolvedFileSystemPath
  }
}
