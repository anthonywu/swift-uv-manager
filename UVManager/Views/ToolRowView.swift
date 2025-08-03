import SwiftUI

struct ToolRowView: View {
    let tool: UVTool
    
    var accessibilityLabel: String {
        var label = "\(tool.name) version \(tool.version)"
        if !tool.executables.isEmpty {
            label += ", provides commands: \(tool.executables.map(\.name).joined(separator: ", "))"
        }
        if !tool.extras.isEmpty {
            label += ", with \(tool.extras.count) extras"
        }
        if !tool.withPackages.isEmpty {
            label += ", with \(tool.withPackages.count) additional packages"
        }
        return label
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tool.name)
                        .font(.headline)
                    
                    Text("v\(tool.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                
                if !tool.executables.isEmpty {
                    Text(tool.executables.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    if !tool.extras.isEmpty {
                        Label("\(tool.extras.count) extras", systemImage: "puzzlepiece")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    if !tool.withPackages.isEmpty {
                        Label("\(tool.withPackages.count) deps", systemImage: "link")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    
                    if tool.versionSpecifier != nil {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Select to view details and manage this tool")
    }
}