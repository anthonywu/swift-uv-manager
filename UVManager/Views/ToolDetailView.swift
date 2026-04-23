import SwiftUI

struct ToolDetailView: View {
  let tool: UVTool
  @EnvironmentObject var uvManager: UVManager
  @State private var showUpgradeAlert = false
  @State private var showUninstallAlert = false
  @State private var showTerminalOutput = false
  @State private var isPerformingAction = false

  private var currentTool: UVTool? {
    uvManager.tools.first { $0.name == tool.name }
  }

  var body: some View {
    Group {
      if let currentTool {
        VStack(spacing: 0) {
          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              summarySection(currentTool)

              if !currentTool.executables.isEmpty {
                executablesSection(currentTool)
              }

              if !currentTool.withPackages.isEmpty || !currentTool.extras.isEmpty {
                dependenciesSection(currentTool)
              }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
          }

          Divider()
          actionBar(currentTool)
        }
        .navigationTitle(currentTool.name)
        .navigationSubtitle("Version \(currentTool.version)")
      } else {
        EmptyStateView()
      }
    }
    .alert("Upgrade Tool", isPresented: $showUpgradeAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Upgrade") {
        showTerminalOutput = true
        Task {
          isPerformingAction = true
          do {
            try await uvManager.upgradeTool(name: currentTool?.name ?? tool.name)
          } catch {
            print("Upgrade failed: \(error)")
          }
          isPerformingAction = false
        }
      }
    } message: {
      Text(
        "Are you sure you want to upgrade \(currentTool?.name ?? tool.name)? This will update to the latest version available on PyPI."
      )
    }
    .sheet(isPresented: $showTerminalOutput) {
      EnhancedTerminalView(processManager: uvManager.processManager)
        .frame(width: 700, height: 500)
    }
    .alert("Uninstall Tool", isPresented: $showUninstallAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Uninstall", role: .destructive) {
        Task {
          isPerformingAction = true
          do {
            try await uvManager.uninstallTool(name: currentTool?.name ?? tool.name)
          } catch {
            print("Uninstall failed: \(error)")
          }
          isPerformingAction = false
        }
      }
    } message: {
      Text(
        "Are you sure you want to uninstall \(currentTool?.name ?? tool.name)? This will remove all executables and the tool's virtual environment."
      )
    }
  }

  private func summarySection(_ currentTool: UVTool) -> some View {
    DetailSection(title: "Package", systemImage: "shippingbox") {
      LabeledContent("Version") {
        Text(currentTool.version)
          .textSelection(.enabled)
      }

      if let specifier = currentTool.versionSpecifier {
        LabeledContent("Version Specifier") {
          HStack(spacing: 8) {
            StatusBadge(text: "Pinned", color: .orange)
            Text(specifier)
              .textSelection(.enabled)
          }
        }
      }

      LabeledContent("Install Location") {
        PathValue(value: currentTool.path, lineLimit: 2)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func executablesSection(_ currentTool: UVTool) -> some View {
    DetailSection(title: "Executables", systemImage: "terminal") {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(currentTool.executables.enumerated()), id: \.element.id) {
          index, executable in
          HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(executable.name)
              .font(.system(.body, design: .monospaced))
              .fontWeight(.medium)
              .textSelection(.enabled)
              .frame(minWidth: 120, alignment: .leading)

            PathValue(value: executable.path)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 7)

          if index < currentTool.executables.count - 1 {
            Divider()
          }
        }
      }
    }
  }

  private func dependenciesSection(_ currentTool: UVTool) -> some View {
    DetailSection(title: "Dependencies & Extras", systemImage: "link") {
      if !currentTool.withPackages.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Additional Packages")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          FlowLayout(spacing: 8) {
            ForEach(currentTool.withPackages, id: \.self) { package in
              StatusBadge(text: package, color: .green)
            }
          }
        }
      }

      if !currentTool.extras.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Extras")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          FlowLayout(spacing: 8) {
            ForEach(currentTool.extras, id: \.self) { extra in
              StatusBadge(text: extra, color: .accentColor)
            }
          }
        }
      }
    }
  }

  private func actionBar(_ currentTool: UVTool) -> some View {
    HStack(spacing: 10) {
      if let url = currentTool.pypiURL {
        Link(destination: url) {
          Label("View on PyPI", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.bordered)
      }

      Spacer()

      Button {
        showUpgradeAlert = true
      } label: {
        Label("Upgrade", systemImage: "arrow.up.circle")
      }
      .buttonStyle(.borderedProminent)
      .disabled(isPerformingAction)

      Button {
        showUninstallAlert = true
      } label: {
        Label("Uninstall", systemImage: "trash")
      }
      .buttonStyle(.bordered)
      .disabled(isPerformingAction)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = FlowResult(
      in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
    return CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: result.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
    for (index, subview) in subviews.enumerated() {
      subview.place(
        at: CGPoint(
          x: result.frames[index].origin.x + bounds.minX,
          y: result.frames[index].origin.y + bounds.minY),
        proposal: ProposedViewSize(result.frames[index].size))
    }
  }

  struct FlowResult {
    var frames: [CGRect] = []
    var height: CGFloat = 0

    init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
      var currentX: CGFloat = 0
      var currentY: CGFloat = 0
      var lineHeight: CGFloat = 0

      for subview in subviews {
        let size = subview.sizeThatFits(.unspecified)

        if currentX + size.width > width && currentX > 0 {
          currentX = 0
          currentY += lineHeight + spacing
          lineHeight = 0
        }

        frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
        currentX += size.width + spacing
        lineHeight = max(lineHeight, size.height)
      }

      height = currentY + lineHeight
    }
  }
}
