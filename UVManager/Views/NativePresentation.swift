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
