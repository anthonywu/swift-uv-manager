import SwiftUI

enum SidebarDestination: Hashable {
  case python
  case systemInfo
  case tool(String)
}

struct ContentView: View {
  @EnvironmentObject var uvManager: UVManager
  @State private var selectedDestination: SidebarDestination?
  @State private var searchText = ""
  @State private var showInstallSheet = false
  @State private var showError = false
  @State private var navigationKeyMonitor: Any?
  @State private var columnVisibility = NavigationSplitViewVisibility.all

  var filteredTools: [UVTool] {
    if searchText.isEmpty {
      return uvManager.tools
    }
    return uvManager.tools.filter { tool in
      tool.name.localizedCaseInsensitiveContains(searchText)
        || tool.version.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var isRefreshingSelectedArea: Bool {
    if selectedDestination == .python {
      return uvManager.isPythonLoading
    }

    if selectedDestination == .systemInfo {
      return uvManager.isCacheLoading
    }

    return uvManager.isLoading
  }

  private var sidebarDestinations: [SidebarDestination] {
    guard !uvManager.installations.isEmpty else { return [] }

    return [.python, .systemInfo] + filteredTools.map { .tool($0.name) }
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
    } detail: {
      if uvManager.installations.isEmpty {
        NoUVInstalledView()
      } else if selectedDestination == .python {
        PythonManagerView()
      } else if selectedDestination == .systemInfo {
        SystemInfoView()
      } else if case .tool(let toolName) = selectedDestination,
        let tool = uvManager.tools.first(where: { $0.name == toolName })
      {
        ToolDetailView(tool: tool)
      } else {
        EmptyStateView()
      }
    }
    .navigationSplitViewStyle(.balanced)
    .searchable(text: $searchText, placement: .sidebar)
    .sheet(isPresented: $showInstallSheet) {
      InstallToolView()
    }
    .alert("Error", isPresented: $showError, presenting: uvManager.lastError) { _ in
      Button("OK") { uvManager.lastError = nil }
    } message: { error in
      Text(error)
    }
    .onChange(of: uvManager.lastError) { _, newValue in
      showError = newValue != nil
    }
    .onAppear {
      installNavigationKeyMonitor()
      selectDefaultDestinationIfNeeded()
    }
    .onDisappear {
      removeNavigationKeyMonitor()
    }
    .onChange(of: uvManager.installations) { _, _ in
      selectDefaultDestinationIfNeeded()
    }
    .onChange(of: uvManager.tools) { _, _ in
      selectDefaultDestinationIfNeeded()
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        if uvManager.installations.count > 1 {
          Picker("UV Version", selection: $uvManager.selectedInstallation) {
            ForEach(uvManager.installations) { installation in
              Text(installation.displayName)
                .tag(installation as UVInstallation?)
            }
          }
          .pickerStyle(.menu)
          .onChange(of: uvManager.selectedInstallation) { _, _ in
            Task {
              await uvManager.fetchToolsDirectory()
              await uvManager.fetchCacheInfo()
              await uvManager.fetchTools()
              await uvManager.fetchPythonRuntimes()
            }
          }
        } else if let installation = uvManager.selectedInstallation {
          Text("UV \(installation.version)")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        Button {
          Task {
            if selectedDestination == .python {
              await uvManager.fetchPythonRuntimes()
            } else if selectedDestination == .systemInfo {
              await uvManager.fetchToolsDirectory()
              await uvManager.fetchCacheInfo()
            } else {
              await uvManager.fetchTools()
            }
          }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh the selected view")
        .disabled(isRefreshingSelectedArea)
        .rotationEffect(.degrees(isRefreshingSelectedArea ? 360 : 0))
        .animation(
          isRefreshingSelectedArea
            ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
          value: isRefreshingSelectedArea)
      }
    }
  }

  @ViewBuilder
  private var sidebar: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        List(selection: $selectedDestination) {
          if uvManager.installations.isEmpty {
            Label("UV Not Found", systemImage: "exclamationmark.triangle")
              .foregroundStyle(.secondary)
          } else {
            Section {
              Label {
                Text("Python Versions")
              } icon: {
                PythonLogoIcon()
              }
              .tag(SidebarDestination.python)
              .id(SidebarDestination.python)

              Label {
                Text("UV System Info")
              } icon: {
                Image(systemName: "info.circle")
              }
              .tag(SidebarDestination.systemInfo)
              .id(SidebarDestination.systemInfo)
            } header: {
              Text("Runtime")
            }

            Section {
              ForEach(filteredTools) { tool in
                let destination = SidebarDestination.tool(tool.name)
                ToolRowView(tool: tool)
                  .tag(destination)
                  .id(destination)
              }
            } header: {
              HStack {
                Text("Installed Tools")
                Spacer()
                Text("\(filteredTools.count)")
                  .foregroundStyle(.secondary)
                Button {
                  showInstallSheet = true
                } label: {
                  Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Install a Python tool")
                .accessibilityLabel("Install Tool")
              }
            }

            if !filteredTools.isEmpty {
              Section {
                BulkActionsView()
              }
            }
          }
        }
        .listStyle(.sidebar)
        .onChange(of: selectedDestination) { _, newValue in
          scrollToSidebarSelection(newValue, proxy: proxy)
        }
      }
    }
    .navigationTitle("UV Manager")
    .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
  }

  private func selectDefaultDestinationIfNeeded() {
    guard !uvManager.installations.isEmpty else {
      selectedDestination = nil
      return
    }

    if let selectedDestination,
      sidebarDestinations.contains(selectedDestination)
    {
      return
    }

    if let firstTool = filteredTools.first {
      selectedDestination = .tool(firstTool.name)
    } else {
      selectedDestination = .python
    }
  }

  private func installNavigationKeyMonitor() {
    guard navigationKeyMonitor == nil else { return }

    navigationKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      guard let direction = sidebarNavigationDirection(for: event) else {
        return event
      }

      moveSidebarSelection(by: direction)
      return nil
    }
  }

  private func removeNavigationKeyMonitor() {
    guard let navigationKeyMonitor else { return }

    NSEvent.removeMonitor(navigationKeyMonitor)
    self.navigationKeyMonitor = nil
  }

  private func scrollToSidebarSelection(_ destination: SidebarDestination?, proxy: ScrollViewProxy)
  {
    guard let destination,
      sidebarDestinations.contains(destination)
    else {
      return
    }

    withAnimation(.easeInOut(duration: 0.12)) {
      proxy.scrollTo(destination, anchor: .center)
    }
  }

  private func sidebarNavigationDirection(for event: NSEvent) -> Int? {
    guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
      NSApp.keyWindow?.attachedSheet == nil,
      !textEntryIsActive
    else {
      return nil
    }

    switch event.charactersIgnoringModifiers {
    case "j":
      return 1
    case "k":
      return -1
    default:
      return nil
    }
  }

  private var textEntryIsActive: Bool {
    guard let responder = NSApp.keyWindow?.firstResponder else { return false }

    if responder is NSTextView || responder is NSTextField {
      return true
    }

    guard let view = responder as? NSView else { return false }

    if view is NSTextField || view is NSSearchField {
      return true
    }

    var parent = view.superview
    while let currentParent = parent {
      if currentParent is NSTextField || currentParent is NSSearchField {
        return true
      }

      parent = currentParent.superview
    }

    return false
  }

  private func moveSidebarSelection(by offset: Int) {
    let destinations = sidebarDestinations
    guard !destinations.isEmpty else { return }

    guard let selectedDestination,
      let selectedIndex = destinations.firstIndex(of: selectedDestination)
    else {
      self.selectedDestination = offset > 0 ? destinations.first : destinations.last
      return
    }

    let nextIndex = min(max(selectedIndex + offset, 0), destinations.count - 1)
    self.selectedDestination = destinations[nextIndex]
  }
}

struct PythonLogoIcon: View {
  var width: CGFloat = 18
  var height: CGFloat = 18

  var body: some View {
    if let image = pythonLogoImage {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: width, height: height)
    } else {
      Image(systemName: "curlybraces")
        .frame(width: width, height: height)
    }
  }

  private var pythonLogoImage: NSImage? {
    guard let url = Bundle.module.url(forResource: "python-logo", withExtension: "svg") else {
      return nil
    }

    return NSImage(contentsOf: url)
  }
}

struct EmptyStateView: View {
  @State private var showInstallSheet = false

  var body: some View {
    ContentUnavailableView {
      Label("No Tool Selected", systemImage: "shippingbox")
    } description: {
      Text("Select a tool in the sidebar to view its executables, packages, and install path.")
    } actions: {
      Button {
        showInstallSheet = true
      } label: {
        Label("Install Tool", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $showInstallSheet) {
      InstallToolView()
    }
  }
}
