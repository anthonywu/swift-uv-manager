import Foundation

struct UVTool: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let version: String
    var path: String
    var versionSpecifier: String?
    var extras: [String] = []
    var withPackages: [String] = []
    var executables: [Executable] = []
    
    var pypiURL: URL? {
        URL(string: "https://pypi.org/project/\(name)/")
    }
    
    struct Executable: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let path: String
    }
}

struct UVInstallation: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let version: String
    let versionDate: String?
    
    var displayName: String {
        "\(version) - \(path)"
    }
    
    static func parse(from versionOutput: String) -> (version: String, date: String?)? {
        let pattern = #"uv\s+(\d+\.\d+\.\d+)(?:\s+\(([^)]+)\))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: versionOutput, range: NSRange(versionOutput.startIndex..., in: versionOutput)),
              let versionRange = Range(match.range(at: 1), in: versionOutput) else {
            return nil
        }
        
        let version = String(versionOutput[versionRange])
        var date: String? = nil
        
        if let dateRange = Range(match.range(at: 2), in: versionOutput) {
            date = String(versionOutput[dateRange])
        }
        
        return (version, date)
    }
}