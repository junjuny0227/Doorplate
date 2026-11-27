import AppKit
import DoorplateCore
import Testing

@testable import DoorplateMenu

@MainActor private final class RecordingHandler: MenuCommandHandler {
  var commands: [MenuCommand] = []
  func perform(_ command: MenuCommand) { commands.append(command) }
}

@Suite @MainActor struct MenuBuilderTests {
  private let handler = RecordingHandler()
  private let builder: MenuBuilder
  private let menu = NSMenu()

  init() {
    _ = NSApplication.shared
    builder = MenuBuilder(handler: handler, home: "/Users/dev", now: { menuNow })
  }

  private func populate(_ result: ScanOutcome? = nil, state: MenuState = MenuState()) {
    builder.populate(menu, outcome: result, state: state)
  }
  private func row(_ id: String = "pid:101") throws -> NSMenuItem {
    try #require(menu.items.first { $0.identifier?.rawValue == id && !$0.isAlternate })
  }
  private func submenu() throws -> NSMenu { try #require(row().submenu) }
  private func choose(_ item: NSMenuItem) throws {
    let action = try #require(item.action)
    #expect(NSApp.sendAction(action, to: item.target, from: item))
  }

  @Test func headerShowsRunningCount() {
    populate(outcome(apps: [entry(), entry(id: "pid:102")]))
    #expect(menu.items[0].title == "Running · 2")
    #expect(!menu.items[0].isEnabled)
  }
  @Test func headerShowsFailure() {
    populate(outcome(failedAt: menuNow.addingTimeInterval(-12)))
    #expect(menu.items[0].title == "Update failed · 1m ago")
  }
  @Test func rowTitleFormat() throws {
    populate(outcome(apps: [entry()]))
    #expect(try row().title == "5173  @repot/desktop\tvite")
    populate(
      outcome(apps: [
        entry(
          port: 8080, title: "shop-api", tool: "gradle",
          startedAt: menuNow.addingTimeInterval(-259200), isLongRunning: true)
      ]))
    let item = try row()
    #expect(item.title == "8080  shop-api · 3d\tgradle")
    let text = try #require(item.attributedTitle)
    let suffix = (text.string as NSString).range(of: " · 3d")
    #expect(
      text.attribute(.foregroundColor, at: suffix.location, effectiveRange: nil) as? NSColor
        == .systemOrange)
    #expect(
      text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor != .systemOrange)
    #expect(text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont == .menuFont(ofSize: 0))
    let style = try #require(
      text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
    #expect(style.tabStops.contains { $0.alignment == .right && $0.location == 320 })
  }
  @Test func containerRowTitleAndTool() throws {
    populate(
      outcome(docker: [
        entry(port: 5432, title: "postgres", tool: "shop-postgres-1", section: .docker)
      ]))
    #expect(try row().title == "5432  postgres\tshop-postgres-1")
    #expect(try submenu().items.last?.title == "Stop Container")
  }
  @Test func submenuHasNoInfoLines() throws {
    populate(outcome(apps: [entry()]))
    #expect(try submenu().items.first?.title == "Open in Browser\tlocalhost:5173")
    #expect(try submenu().items.filter { !$0.isEnabled && !$0.isSeparatorItem }.isEmpty)
    populate(outcome(apps: [entry(exposure: .network)]))
    #expect(try submenu().items[0].title == "Open to network")
    #expect(try !submenu().items[0].isEnabled)
    #expect(try submenu().items[1].isSeparatorItem)
    populate(outcome(docker: [entry(section: .docker, exposure: .network)]))
    #expect(try submenu().items.first?.title == "Open in Browser\tlocalhost:5173")
    #expect(try !submenu().items.contains { $0.title == "Open to network" })
  }
  @Test func stopItemShowsPIDInRed() throws {
    populate(outcome(apps: [entry()]))
    let stop = try #require(submenu().items.last)
    #expect(stop.title == "Stop (PID 101)")
    #expect(
      stop.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        == .systemRed)
    populate(outcome(apps: [entry(canTerminate: false)]))
    #expect(try submenu().items.last?.isEnabled == false)
  }
  @Test func refreshKeepsItemsWhenIdsUnchanged() throws {
    populate(outcome(apps: [entry()]))
    let original = try row()
    let originalSubmenu = try submenu()
    let originalStop = try #require(originalSubmenu.items.last)
    var state = MenuState()
    state.stopping = ["pid:101"]
    builder.refresh(menu, outcome: outcome(apps: [entry(title: "changed")]), state: state)
    #expect(try row() === original)
    #expect(try submenu() === originalSubmenu)
    #expect(try submenu().items.last === originalStop)
    #expect(original.title.contains("changed"))
    #expect(!originalStop.isEnabled)
    #expect(originalStop.attributedTitle == nil)
    builder.refresh(
      menu, outcome: outcome(apps: [entry(), entry(id: "pid:102")]), state: MenuState())
    #expect(try row() !== original)
  }
  @Test func branchFollowsTheTitleInGray() throws {
    populate(
      outcome(apps: [
        entry(
          port: 8080, title: "shop-api", tool: "gradle",
          startedAt: menuNow.addingTimeInterval(-259200), isLongRunning: true,
          branch: "feat/pay")
      ]))
    let item = try row()
    #expect(item.title == "8080  shop-api · feat/pay · 3d\tgradle")
    let text = try #require(item.attributedTitle)
    var gray = NSRange()
    let start = (text.string as NSString).range(of: " · feat/pay").location
    #expect(
      text.attribute(.foregroundColor, at: start, effectiveRange: &gray) as? NSColor
        == .secondaryLabelColor)
    #expect(gray == NSRange(location: start, length: (" · feat/pay" as NSString).length))
    // The long-running tag stays orange after the branch; the Option row has no branch.
    let orange = (text.string as NSString).range(of: " · 3d")
    #expect(
      text.attribute(.foregroundColor, at: orange.location, effectiveRange: nil) as? NSColor
        == .systemOrange)
    #expect(menu.items[menu.index(of: item) + 1].title == "Stop 8080 shop-api")
  }
  @Test func longBranchesAreCut() throws {
    populate(outcome(apps: [entry(branch: "feature/JIRA-1234-add-login-page")]))
    #expect(try row().title == "5173  @repot/desktop · feature/JIRA-1234-add-l…\tvite")
    #expect(MenuBuilder.shortBranch(String(repeating: "b", count: 24)).count == 24)
  }
  @Test func noBranchOnDockerRowsOrWithoutOne() throws {
    populate(
      outcome(
        apps: [entry()],
        docker: [
          entry(
            port: 5432, title: "db", tool: "shop-db", section: .docker, id: "docker:abc",
            branch: "main")
        ], dockerStatus: .ok))
    #expect(try row().title == "5173  @repot/desktop\tvite")
    #expect(try row("docker:abc").title == "5432  db\tshop-db")
  }
  private func acme(_ state: MenuState = MenuState(), canTerminate: Bool = true) {
    let root = "/Users/dev/acme"
    populate(
      outcome(apps: [
        entry(
          port: 3000, title: "@acme/site", id: "pid:101", pid: 101, directory: root + "/site",
          root: root, canTerminate: canTerminate, branch: "main"),
        entry(
          port: 5173, title: "@acme/web", id: "pid:102", pid: 102, directory: root + "/web",
          root: root, canTerminate: canTerminate, branch: "main"),
        entry(
          port: 8080, title: "shop-api", tool: "gradle", id: "pid:103", pid: 103,
          root: "/Users/dev/shop"),
      ]), state: state)
  }

  @Test func groupHeaderThenIndentedRows() throws {
    acme()
    let header = try row("group:/Users/dev/acme")
    #expect(header.title == "acme · main\t2 servers")
    #expect(header.image == nil && header.indentationLevel == 0)
    let index = menu.index(of: header)
    let ids = menu.items[index...].filter { !$0.isAlternate }.prefix(4).map {
      $0.identifier?.rawValue
    }
    #expect(ids == ["group:/Users/dev/acme", "pid:101", "pid:102", "pid:103"])
    // Rows inside the group are indented and leave the branch to the header.
    #expect(try row("pid:101").title == "3000  @acme/site\tvite")
    #expect(try row("pid:101").indentationLevel == 1)
    #expect(menu.items[menu.index(of: try row("pid:101")) + 1].indentationLevel == 1)
    // A project with one server keeps today's row.
    #expect(try row("pid:103").indentationLevel == 0)
    let gray = try #require(header.attributedTitle)
    #expect(
      gray.attribute(
        .foregroundColor, at: (gray.string as NSString).range(of: " · main").location,
        effectiveRange: nil)
        as? NSColor == .secondaryLabelColor)
  }

  @Test func groupSubmenuOpensTheFolderAndStopsAll() throws {
    acme()
    let items = try #require(try row("group:/Users/dev/acme").submenu).items
    #expect(items.map(\.title) == ["Show in Finder", "Open in Terminal", "", "Stop All (2)"])
    #expect(
      items.last?.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil)
        as? NSColor == .systemRed)
    try choose(items[0])
    try choose(items[3])
    #expect(handler.commands.first == .revealInFinder("/Users/dev/acme"))
    guard case .stopAll(let refs, let name) = handler.commands.last else {
      Issue.record("expected stopAll")
      return
    }
    #expect(name == "acme")
    #expect(refs.map(\.id) == ["pid:101", "pid:102"])
  }

  @Test func groupAlternateStopsAllWithOnlyTheStopWordRed() throws {
    acme()
    let index = menu.index(of: try row("group:/Users/dev/acme"))
    let alternate = menu.items[index + 1]
    #expect(alternate.isAlternate && alternate.keyEquivalentModifierMask == .option)
    #expect(alternate.title == "Stop acme (2 servers)")
    var red = NSRange()
    #expect(
      alternate.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: &red)
        as? NSColor == .systemRed)
    #expect(red == NSRange(location: 0, length: 4))
  }

  @Test func stoppingRowsLeaveTheGroup() throws {
    var state = MenuState()
    state.stopping = ["pid:101"]
    acme(state)
    let items = try #require(try row("group:/Users/dev/acme").submenu).items
    #expect(items.last?.title == "Stop All (1)")
    state.stopping = ["pid:101", "pid:102"]
    acme(state)
    let stop = try #require(try row("group:/Users/dev/acme").submenu?.items.last)
    #expect(stop.title == "Stop All (0)" && !stop.isEnabled && stop.attributedTitle == nil)
    #expect(menu.items[menu.index(of: try row("group:/Users/dev/acme")) + 1].isAlternate == false)
  }

  @Test func unstoppableGroupsHaveNoStopItem() throws {
    acme(canTerminate: false)
    let items = try #require(try row("group:/Users/dev/acme").submenu).items
    #expect(items.map(\.title) == ["Show in Finder", "Open in Terminal"])
  }

  @Test func dockerGroupsShowTheComposeFolder() throws {
    func container(_ port: UInt16, _ name: String) -> ServerEntry {
      entry(
        port: port, title: name, tool: "acme-\(name)", section: .docker, id: "docker:\(name)",
        directory: "/Users/dev/acme", root: nil)
    }
    populate(outcome(docker: [container(5432, "db"), container(6379, "redis")], dockerStatus: .ok))
    let header = try row("group:/Users/dev/acme")
    #expect(header.title == "acme\t2 servers")
    #expect(
      header.submenu?.items.map(\.title) == ["Show Compose Folder in Finder", "", "Stop All (2)"])
    #expect(try row("docker:db").indentationLevel == 1)
  }

  @Test func alternateStopOnlyWhenTerminable() throws {
    populate(outcome(apps: [entry()]))
    let index = menu.index(of: try row())
    #expect(menu.items[index + 1].isAlternate)
    #expect(menu.items[index + 1].keyEquivalentModifierMask == .option)
    #expect(menu.items[index + 1].submenu == nil)
    let title = try #require(menu.items[index + 1].attributedTitle)
    #expect(title.string == "Stop 5173 @repot/desktop")
    // Only the word "Stop" is red; the port and the name keep the normal menu color.
    var red = NSRange()
    #expect(
      title.attribute(.foregroundColor, at: 0, effectiveRange: &red) as? NSColor == .systemRed)
    #expect(red == NSRange(location: 0, length: 4))
    #expect(title.attribute(.foregroundColor, at: 5, effectiveRange: nil) == nil)
    populate(outcome(apps: [entry(canTerminate: false)]))
    #expect(!menu.items.contains(where: { $0.isAlternate }))
  }
  @Test func stoppingRowDisablesStop() throws {
    var state = MenuState()
    state.stopping = ["pid:101"]
    populate(outcome(apps: [entry()]), state: state)
    #expect(try row().title.contains("Stopping…"))
    #expect(!menu.items.contains(where: { $0.isAlternate }))
    #expect(try submenu().items.last?.isEnabled == false)
    #expect(try submenu().items.last?.attributedTitle == nil)
  }
  @Test func shownRuntimeHasNoStopItem() throws {
    populate(
      outcome(apps: [entry(title: "OrbStack", section: .hidden(.otherApp), canTerminate: false)]))
    let items = try submenu().items
    #expect(!items.contains { $0.title.hasPrefix("Stop") })
    #expect(items.last?.isSeparatorItem == false)
    #expect(!menu.items.contains(where: { $0.isAlternate }))
  }
  @Test func shownOtherAppCanBeStopped() throws {
    populate(outcome(apps: [entry(title: "Spotify", section: .hidden(.otherApp))]))
    #expect(try submenu().items.last?.title == "Stop (PID 101)")
    #expect(try submenu().items.last?.isEnabled == true)
    #expect(menu.items.contains(where: { $0.isAlternate }))
  }
  @Test func nonHTTPPutsCopyFirst() throws {
    populate(outcome(apps: [entry(likelyHTTP: false)]))
    #expect(try submenu().items.first?.title == "Copy Address")
    #expect(try !submenu().items.contains { $0.title.contains("Open in Browser") })
  }
  @Test func extrasCopyTheirAddress() throws {
    populate(
      outcome(apps: [entry(extras: [.init(port: 5005, exposure: .loopback, role: .debugger)])]))
    let item = try #require(submenu().items.first { $0.title == "5005  Debugger" })
    try choose(item)
    #expect(handler.commands == [.copy("localhost:5005")])
  }
  @Test func commandCarriesTargetSnapshot() throws {
    let fixture = entry()
    populate(outcome(apps: [fixture]))
    try choose(#require(submenu().items.first))
    try choose(#require(menu.items.first(where: { $0.isAlternate })))
    #expect(
      handler.commands == [
        .openInBrowser(URL(string: "http://localhost:5173")!),
        .stop(EntryRef(id: "pid:101", target: fixture.target, title: "@repot/desktop", port: 5173)),
      ])
  }
  @Test func dockerSectionStates() {
    populate(outcome(dockerStatus: .notResponding))
    #expect(menu.items.contains { $0.title == "Docker" })
    #expect(menu.items.contains { $0.title == "Docker (not responding)" && !$0.isEnabled })
    for status in [DockerStatus.absent, .ok] {
      populate(outcome(dockerStatus: status))
      #expect(!menu.items.contains { $0.title == "Docker" })
    }
  }
  @Test func emptyStateKeepsSystemSection() throws {
    populate(
      outcome(system: [entry(port: 5000, tool: "airplay", section: .system, canTerminate: false)]))
    #expect(menu.items[1].title == "No servers running")
    #expect(menu.items[2].isSeparatorItem)
    #expect(try row().title.contains("AirPlay Receiver (macOS)"))
    #expect(!menu.items.contains(where: { $0.isAlternate }))
    #expect(try submenu().items.count == 1)
    #expect(try !submenu().items[0].isEnabled)
  }
  @Test func hiddenSubmenuIsInfoOnly() throws {
    populate(outcome(hidden: [entry(), entry(port: 3000)]))
    let hidden = try #require(menu.items.first { $0.title == "2 hidden" }?.submenu)
    #expect(hidden.items.count == 2)
    #expect(hidden.items.allSatisfy { !$0.isEnabled && $0.action == nil })
  }

  @Test func systemServiceHasCopyInsteadOfAirPlayHintOrStop() throws {
    populate(
      outcome(system: [
        entry(port: 49152, title: "rapportd", tool: nil, section: .system, canTerminate: false)
      ]))
    #expect(try row().title == "49152  rapportd")
    #expect(!menu.items.contains(where: { $0.isAlternate }))
    let items = try submenu().items
    #expect(items.map { $0.identifier?.rawValue } == ["copy"])
    try choose(#require(items.first))
    #expect(handler.commands == [.copy("localhost:49152")])
  }

  @Test func systemSettingMovesEntriesWithoutChangingServerCount() throws {
    let entries = [
      entry(port: 5000, tool: "airplay", section: .system, canTerminate: false),
      entry(
        port: 49152, title: "rapportd", tool: nil, section: .system, id: "pid:102",
        canTerminate: false),
    ]
    func result(_ showSystemPorts: Bool) -> ScanOutcome {
      ScanOutcome(
        snapshot: SnapshotBuilder.build(
          entries, dockerStatus: .absent, settings: .init(showSystemPorts: showSystemPorts),
          now: menuNow), failedAt: nil)
    }

    populate(result(false))
    #expect(menu.items[0].title == L10n.format(.headerRunning, 0))
    #expect(menu.items.contains { $0.identifier?.rawValue == "empty" })
    #expect(!menu.items.contains { $0.identifier?.rawValue == "system.separator" })
    let hidden = try #require(menu.items.first { $0.identifier?.rawValue == "hidden" }?.submenu)
    #expect(hidden.items.map(\.title) == ["5000  \(L10n.text(.systemAirplay))", "49152  rapportd"])
    #expect(hidden.items.allSatisfy { !$0.isEnabled && $0.action == nil && $0.submenu == nil })

    builder.refresh(menu, outcome: result(true), state: MenuState())
    #expect(menu.items[0].title == L10n.format(.headerRunning, 0))
    #expect(try row().title == "5000  \(L10n.text(.systemAirplay))")
    #expect(!menu.items.contains { $0.identifier?.rawValue == "hidden" || $0.isAlternate })

    builder.refresh(menu, outcome: result(false), state: MenuState())
    #expect(!menu.items.contains { $0.identifier?.rawValue == "system.separator" })
    #expect(
      menu.items.first { $0.identifier?.rawValue == "hidden" }?.title == L10n.format(.menuHidden, 2)
    )
  }
  @Test func footerItems() throws {
    populate()
    #expect(menu.items.suffix(2).map(\.title) == ["Settings…", "Quit Doorplate"])
    #expect(menu.items.suffix(2).map(\.keyEquivalent) == [",", "q"])
    let url = URL(string: "https://example.com/release")!
    var state = MenuState()
    state.update = .available(version: "0.2.0", page: url)
    populate(state: state)
    try choose(#require(menu.items.first { $0.title == "Update Available: 0.2.0" }))
    #expect(handler.commands.last == .openUpdatePage(url))
    state.update = .pending(version: "0.2.0")
    populate(state: state)
    try choose(#require(menu.items.first { $0.title == "Update Available: 0.2.0" }))
    #expect(handler.commands.last == .checkForUpdates)
  }
}
