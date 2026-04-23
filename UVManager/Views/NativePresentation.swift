import SwiftUI

struct DetailSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder var content: Content

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Label(title, systemImage: systemImage)
        .font(.headline)
    }
  }
}

struct StatusBadge: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption2)
      .fontWeight(.medium)
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(color.opacity(0.12), in: Capsule())
  }
}

struct FreeThreadedPythonBadge: View {
  private static let documentationURL = URL(
    string: "https://docs.python.org/3/howto/free-threading-python.html")!

  var body: some View {
    Link(destination: Self.documentationURL) {
      StatusBadge(text: "Free-threaded", color: .purple)
    }
    .buttonStyle(.plain)
    .help("Learn about free-threaded Python")
    .accessibilityLabel("Free-threaded Python")
  }
}

struct PythonImplementationBadge: View {
  let runtime: UVPythonRuntime

  var body: some View {
    if let url = documentationURL {
      Link(destination: url) {
        StatusBadge(text: runtime.implementationDisplayName, color: .secondary)
      }
      .buttonStyle(.plain)
      .help("Visit \(runtime.implementationDisplayName)")
      .accessibilityLabel(runtime.implementationDisplayName)
    } else {
      StatusBadge(text: runtime.implementationDisplayName, color: .secondary)
    }
  }

  private var documentationURL: URL? {
    switch runtime.implementation.lowercased() {
    case "pypy":
      return URL(string: "https://pypy.org/")
    case "graalpy":
      return URL(string: "https://www.graalvm.org/python/")
    default:
      return nil
    }
  }
}

struct RuntimeInstallSourceBadge: View {
  let runtime: UVPythonRuntime

  private static let uvManagedPythonURL = URL(
    string: "https://docs.astral.sh/uv/guides/install-python/")!

  var body: some View {
    if runtime.isUvManaged {
      Link(destination: Self.uvManagedPythonURL) {
        StatusBadge(text: runtime.installSourceLabel, color: badgeColor)
      }
      .buttonStyle(.plain)
      .help("Learn about uv-managed Python")
      .accessibilityLabel("uv-managed Python")
    } else {
      StatusBadge(text: runtime.installSourceLabel, color: badgeColor)
    }
  }

  private var badgeColor: Color {
    if runtime.isUvManaged {
      return .green
    }

    if runtime.isSystemPython {
      return .blue
    }

    return .orange
  }
}

struct PathValue: View {
  let value: String
  var lineLimit: Int? = 1

  var body: some View {
    Text(value)
      .font(.system(.callout, design: .monospaced))
      .lineLimit(lineLimit)
      .truncationMode(.middle)
      .textSelection(.enabled)
  }
}
