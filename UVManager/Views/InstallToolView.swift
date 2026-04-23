import SwiftUI

struct InstallToolView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var uvManager: UVManager

  @State private var packageName = ""
  @State private var additionalPackages: [String] = []
  @State private var newPackage = ""
  @State private var forceInstall = false
  @State private var isInstalling = false
  @State private var showTerminalOutput = false

  var body: some View {
    VStack(spacing: 0) {
      headerSection

      Divider()

      Form {
        packageSection
        additionalPackagesSection
        optionsSection
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)

      Divider()

      actionButtons
    }
    .frame(width: 560, height: 440)
    .background(Color(NSColor.windowBackgroundColor))
    .sheet(isPresented: $showTerminalOutput) {
      EnhancedTerminalView(processManager: uvManager.processManager) {
        // Dismiss the install view when terminal is closed
        dismiss()
      }
      .frame(width: 700, height: 500)
    }
  }

  private var headerSection: some View {
    HStack(spacing: 10) {
      Image(systemName: "plus.circle")
        .font(.title3)
        .foregroundStyle(Color.accentColor)

      VStack(alignment: .leading, spacing: 2) {
        Text("Install Python Tool")
          .font(.headline)

        Text("Install a tool from PyPI with optional dependencies.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var packageSection: some View {
    Section("Package") {
      HStack {
        TextField("e.g. ruff, black, pytest", text: $packageName)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel("Package name")
          .accessibilityHint("Enter the exact package name as it appears on PyPI")

        if !packageName.isEmpty {
          Link(destination: URL(string: "https://pypi.org/project/\(packageName)/")!) {
            Image(systemName: "arrow.up.right.square")
          }
          .help("View on PyPI")
          .accessibilityLabel("View \(packageName) on PyPI")
        }
      }

      Text("Enter the exact package name as it appears on PyPI.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var additionalPackagesSection: some View {
    Section("Additional Packages") {
      HStack {
        TextField("e.g. pandas, numpy", text: $newPackage)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            addPackage()
          }
          .accessibilityLabel("Additional package name")
          .accessibilityHint("Press return to add package to the list")

        Button("Add", action: addPackage)
          .disabled(newPackage.isEmpty)
      }

      if !additionalPackages.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(additionalPackages, id: \.self) { package in
              HStack(spacing: 4) {
                Text(package)
                  .font(.caption)

                Button {
                  additionalPackages.removeAll { $0 == package }
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(.green.opacity(0.2), in: Capsule())
            }
          }
        }
      }

      Text("These packages will be installed in the same virtual environment.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var optionsSection: some View {
    Section("Options") {
      Toggle(isOn: $forceInstall) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Force Install")
          Text("Reinstall the tool even if it already exists")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityLabel("Force install")
      .accessibilityHint("When enabled, reinstalls the tool even if it already exists")
    }
  }

  private var actionButtons: some View {
    HStack {
      Button("Cancel") {
        dismiss()
      }
      .keyboardShortcut(.escape)

      Spacer()

      Button {
        showTerminalOutput = true
        install()
      } label: {
        Label("Install", systemImage: "arrow.down.circle")
      }
      .keyboardShortcut(.return)
      .buttonStyle(.borderedProminent)
      .disabled(packageName.isEmpty || isInstalling)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private func addPackage() {
    let trimmed = newPackage.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty && !additionalPackages.contains(trimmed) {
      additionalPackages.append(trimmed)
      newPackage = ""
    }
  }

  private func install() {
    isInstalling = true

    Task {
      do {
        try await uvManager.installTool(
          name: packageName,
          withPackages: additionalPackages,
          force: forceInstall
        )

        // Don't dismiss immediately - let the user close the terminal
        // The view will be dismissed when they close the terminal sheet
      } catch {
        print("Installation failed: \(error)")
      }

      await MainActor.run {
        isInstalling = false
      }
    }
  }
}
