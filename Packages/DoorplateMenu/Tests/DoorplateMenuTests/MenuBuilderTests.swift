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
  @Test func alternateStopOnlyWhenTerminable() throws {
    populate(outcome(apps: [entry()]))
    let index = menu.index(of: try row())
    #expect(menu.items[index + 1].isAlternate)
    #expect(menu.items[index + 1].keyEquivalentModifierMask == .option)
    #expect(menu.items[index + 1].submenu == nil)
    let red = try #require(menu.items[index + 1].attributedTitle)
    #expect(red.string == "Stop 5173 @repot/desktop")
    #expect(red.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemRed)
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
