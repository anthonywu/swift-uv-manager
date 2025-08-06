import Foundation
import Combine

@MainActor
class UVManager: ObservableObject {
    @Published var installations: [UVInstallation] = []
    @Published var selectedInstallation: UVInstallation?
    @Published var tools: [UVTool] = []
    @Published var isLoading = false
    @Published var toolsDirectory = ""
    @Published var lastError: String?
    
    let processManager = ProcessManager()
    
    init() {
        Task {
            await detectUVInstallations()
            await fetchToolsDirectory()
            await fetchTools()
        }
    }
    
    func detectUVInstallations() async {
        isLoading = true
        defer { isLoading = false }
        
        var detectedInstallations: [UVInstallation] = []
        
        // Common UV installation locations
        let commonPaths = [
            NSHomeDirectory() + "/.local/bin/uv",
            "/usr/local/bin/uv",
            "/opt/homebrew/bin/uv",
            "/usr/bin/uv"
        ]
        
        // First check common paths
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                do {
                    let (versionOutput, _) = try await processManager.run(path, arguments: ["--version"])
                    if let (version, date) = UVInstallation.parse(from: versionOutput) {
                        let installation = UVInstallation(path: path, version: version, versionDate: date)
                        detectedInstallations.append(installation)
                    }
                } catch {
                    print("Failed to get version for \(path): \(error)")
                }
            }
        }
        
        // Also try which command as fallback
        do {
            let (output, _) = try await processManager.run("/usr/bin/which", arguments: ["-a", "uv"])
            let paths = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
            
            for path in paths where !path.isEmpty && !commonPaths.contains(path) {
                do {
                    let (versionOutput, _) = try await processManager.run(path, arguments: ["--version"])
                    if let (version, date) = UVInstallation.parse(from: versionOutput) {
                        let installation = UVInstallation(path: path, version: version, versionDate: date)
                        detectedInstallations.append(installation)
                    }
                } catch {
                    print("Failed to get version for \(path): \(error)")
                }
            }
        } catch {
            // which command failed, but we may have found UV in common paths
            // This is expected on some systems, ignore silently
        }
        
        self.installations = detectedInstallations.sorted { v1, v2 in
            v1.version.compare(v2.version, options: .numeric) == .orderedDescending
        }
        
        if !installations.isEmpty && selectedInstallation == nil {
            selectedInstallation = installations.first
        } else if installations.isEmpty {
            lastError = "UV not found. Please install UV first."
        }
    }
    
    func fetchToolsDirectory() async {
        guard let uvPath = selectedInstallation?.path else { return }
        
        do {
            let (output, _) = try await processManager.run(uvPath, arguments: ["tool", "dir", "--color", "never"])
            toolsDirectory = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to fetch tools directory: \(error)")
            lastError = error.localizedDescription
        }
    }
    
    func fetchTools() async {
        guard let uvPath = selectedInstallation?.path else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (output, _) = try await processManager.run(uvPath, arguments: [
                "tool", "list",
                "--show-paths",
                "--show-version-specifiers",
                "--show-with",
                "--show-extras",
                "--color", "never"
            ])
            
            self.tools = parseToolsList(output)
        } catch {
            print("Failed to fetch tools: \(error)")
            lastError = error.localizedDescription
        }
    }
    
    private func parseToolsList(_ output: String) -> [UVTool] {
        var tools: [UVTool] = []
        var currentTool: UVTool?
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("warning:") || trimmed.hasPrefix("hint:") {
                continue
            }
            
            if line.hasPrefix("- ") {
                if var tool = currentTool {
                    let executableLine = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                    let pattern = #"^(.+) \((.+)\)$"#
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: executableLine, range: NSRange(executableLine.startIndex..., in: executableLine)),
                       let nameRange = Range(match.range(at: 1), in: executableLine),
                       let pathRange = Range(match.range(at: 2), in: executableLine) {
                        let executable = UVTool.Executable(
                            name: String(executableLine[nameRange]),
                            path: String(executableLine[pathRange])
                        )
                        tool.executables.append(executable)
                        currentTool = tool
                    }
                }
            } else {
                if let tool = currentTool {
                    tools.append(tool)
                }
                
                let pattern = #"^(\S+) v([\d.]+(?:\.post\d+)?(?:a\d+)?)"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      let nameRange = Range(match.range(at: 1), in: line),
                      let versionRange = Range(match.range(at: 2), in: line) else {
                    continue
                }
                
                let name = String(line[nameRange])
                let version = String(line[versionRange])
                
                var tool = UVTool(name: name, version: version, path: "")
                
                // Extract path
                let pathPattern = #"\(([^)]+)\)$"#
                if let pathRegex = try? NSRegularExpression(pattern: pathPattern),
                   let pathMatch = pathRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let pathRange = Range(pathMatch.range(at: 1), in: line) {
                    tool.path = String(line[pathRange])
                }
                
                // Extract version specifier
                let requiredPattern = #"\[required: ([^\]]+)\]"#
                if let requiredRegex = try? NSRegularExpression(pattern: requiredPattern),
                   let requiredMatch = requiredRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let requiredRange = Range(requiredMatch.range(at: 1), in: line) {
                    tool.versionSpecifier = String(line[requiredRange])
                }
                
                // Extract extras
                let extrasPattern = #"\[extras: ([^\]]+)\]"#
                if let extrasRegex = try? NSRegularExpression(pattern: extrasPattern),
                   let extrasMatch = extrasRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let extrasRange = Range(extrasMatch.range(at: 1), in: line) {
                    tool.extras = String(line[extrasRange]).components(separatedBy: ", ")
                }
                
                // Extract with packages
                let withPattern = #"\[with: ([^\]]+)\]"#
                if let withRegex = try? NSRegularExpression(pattern: withPattern),
                   let withMatch = withRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let withRange = Range(withMatch.range(at: 1), in: line) {
                    tool.withPackages = String(line[withRange]).components(separatedBy: ", ")
                }
                
                currentTool = tool
            }
        }
        
        if let tool = currentTool {
            tools.append(tool)
        }
        
        return tools
    }
    
    func installTool(name: String, withPackages: [String] = [], force: Bool = false, useTerminal: Bool = true) async throws {
        guard let uvPath = selectedInstallation?.path else {
            throw ProcessError.notFound
        }
        
        var args = ["tool", "install", name]
        
        if !withPackages.isEmpty {
            args.append("--with")
            args.append(withPackages.joined(separator: ","))
        }
        
        if force {
            args.append("--force")
        }
        
        // Add verbose flag to get more output
        args.append("-v")
        // Disable colors for better terminal compatibility
        args.append("--color")
        args.append("never")
        
        if useTerminal {
            // Use terminal emulator for better visual output
            processManager.runInTerminal(uvPath, arguments: args)
            // Don't auto-dismiss - let user close the terminal when ready
            // We'll refresh tools when the terminal is closed
        } else {
            _ = try await processManager.run(uvPath, arguments: args, streamOutput: true)
            await fetchTools()
        }
    }
    
    func upgradeTool(name: String, useTerminal: Bool = true) async throws {
        guard let uvPath = selectedInstallation?.path else {
            throw ProcessError.notFound
        }
        
        let args = ["tool", "upgrade", name, "-v", "--color", "never"]
        
        if useTerminal {
            processManager.runInTerminal(uvPath, arguments: args)
            // Don't auto-dismiss - let user close the terminal when ready
        } else {
            _ = try await processManager.run(uvPath, arguments: args, streamOutput: true)
            await fetchTools()
        }
    }
    
    func upgradeAllTools(useTerminal: Bool = true) async throws {
        guard let uvPath = selectedInstallation?.path else {
            throw ProcessError.notFound
        }
        
        let args = ["tool", "upgrade", "--all", "-v", "--color", "never"]
        
        if useTerminal {
            processManager.runInTerminal(uvPath, arguments: args)
            // Don't auto-dismiss - let user close the terminal when ready
        } else {
            _ = try await processManager.run(uvPath, arguments: args, streamOutput: true)
            await fetchTools()
        }
    }
    
    func uninstallTool(name: String) async throws {
        guard let uvPath = selectedInstallation?.path else {
            throw ProcessError.notFound
        }
        
        _ = try await processManager.run(uvPath, arguments: ["tool", "uninstall", name, "-v", "--color", "never"], streamOutput: true)
        await fetchTools()
    }
    
    func selfUpdate() async {
        guard let uvPath = selectedInstallation?.path else {
            lastError = "UV installation not found"
            return
        }
        
        // Run uv self update in terminal
        processManager.runInTerminal(uvPath, arguments: ["self", "update", "--color", "never"])
        
        // After update completes, refresh UV installations
        // This will be triggered when the terminal closes via onDisappear
    }
    
    func installUV() async throws {
        let script = "curl -LsSf https://astral.sh/uv/install.sh | sh"
        _ = try await processManager.run("/bin/sh", arguments: ["-c", script], streamOutput: true)
        await detectUVInstallations()
    }
}