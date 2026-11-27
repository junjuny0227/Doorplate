import AppKit
import DoorplateCore

private final class CommandBox {
  let command: MenuCommand
  init(_ command: MenuCommand) { self.command = command }
}

@MainActor public final class MenuBuilder: NSObject {
  private let handler: any MenuCommandHandler
  private let now: () -> Date

  public init(handler: any MenuCommandHandler, home: String, now: @escaping () -> Date) {
    self.handler = handler
    self.now = now
    super.init()
  }

  public func populate(_ menu: NSMenu, outcome: ScanOutcome?, state: MenuState) {
    let desired = makeMenu(outcome: outcome, state: state)
    menu.removeAllItems()
    menu.autoenablesItems = false
    transfer(desired, to: menu)
  }

  public func refresh(_ menu: NSMenu, outcome: ScanOutcome?, state: MenuState) {
    let desired = makeMenu(outcome: outcome, state: state)
    // Alternates can appear/disappear while stopping without replacing the open row.
    let existingLayout = menu.items.filter { !$0.isAlternate }.map(\.identifier)
    let desiredLayout = desired.items.filter { !$0.isAlternate }.map(\.identifier)
    guard existingLayout == desiredLayout else {
      menu.removeAllItems()
      menu.autoenablesItems = false
      transfer(desired, to: menu)
      return
    }
    synchronize(menu, with: desired)
  }

  private func transfer(_ source: NSMenu, to destination: NSMenu) {
    for item in source.items {
      source.removeItem(item)
      destination.addItem(item)
    }
  }

  private func synchronize(_ menu: NSMenu, with desired: NSMenu) {
    let desiredIDs = Set(desired.items.compactMap(\.identifier))
    for item in menu.items
    where !desiredIDs.contains(item.identifier ?? NSUserInterfaceItemIdentifier("")) {
      menu.removeItem(item)
    }
    for (index, replacement) in desired.items.enumerated() {
      guard let item = menu.items.first(where: { $0.identifier == replacement.identifier }) else {
        desired.removeItem(replacement)
        menu.insertItem(replacement, at: index)
        continue
      }
      item.title = replacement.title
      item.attributedTitle = replacement.attributedTitle
      item.image = replacement.image
      item.isEnabled = replacement.isEnabled
      item.representedObject = replacement.representedObject
      item.target = replacement.target
      item.action = replacement.action
      item.keyEquivalent = replacement.keyEquivalent
      item.keyEquivalentModifierMask = replacement.keyEquivalentModifierMask
      item.isAlternate = replacement.isAlternate
      item.indentationLevel = replacement.indentationLevel
      if let submenu = item.submenu, let newSubmenu = replacement.submenu {
        synchronize(submenu, with: newSubmenu)
      } else {
        item.submenu = replacement.submenu
      }
      if menu.index(of: item) != index {
        menu.removeItem(item)
        menu.insertItem(item, at: index)
      }
    }
  }

  private func makeMenu(outcome: ScanOutcome?, state: MenuState) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    let snapshot = outcome?.snapshot ?? .empty(at: now())
    let header: String
    if let failedAt = outcome?.failedAt {
      header = L10n.format(.headerFailed, DurationText.short(now().timeIntervalSince(failedAt)))
    } else {
      header = L10n.format(.headerRunning, snapshot.badgeCount)
    }
    menu.addItem(item(header, id: "header"))
    if snapshot.apps.isEmpty && snapshot.docker.isEmpty {
      menu.addItem(item(L10n.text(.menuEmpty), id: "empty"))
    }
    appendGrouped(snapshot.apps, to: menu, state: state)
    if !snapshot.system.isEmpty {
      separator(menu, id: "system.separator")
      append(snapshot.system, to: menu, state: state)
    }
    if !snapshot.docker.isEmpty || snapshot.dockerStatus == .notResponding {
      separator(menu, id: "docker.separator")
      menu.addItem(item(L10n.text(.menuDocker), id: "docker.header"))
      if snapshot.dockerStatus == .notResponding {
        menu.addItem(item(L10n.text(.menuDockerNotResponding), id: "docker.failure"))
      }
      appendGrouped(
        snapshot.docker, to: menu, state: state,
        dockerUnavailable: snapshot.dockerStatus == .notResponding)
    }
    if !snapshot.hidden.isEmpty {
      separator(menu, id: "hidden.separator")
      let hidden = item(L10n.format(.menuHidden, snapshot.hidden.count), id: "hidden")
      let submenu = NSMenu()
      submenu.autoenablesItems = false
      for entry in snapshot.hidden {
        submenu.addItem(item("\(entry.primary.port)  \(displayTitle(entry))", id: entry.id))
      }
      hidden.submenu = submenu
      hidden.isEnabled = true
      menu.addItem(hidden)
    }
    separator(menu, id: "footer.separator")
    switch state.update {
    case .none: break
    case .checkForUpdates:
      menu.addItem(item(L10n.text(.menuCheckForUpdates), id: "update", command: .checkForUpdates))
    case .available(let version, let page):
      menu.addItem(
        item(
          L10n.format(.menuUpdateAvailable, version), id: "update", command: .openUpdatePage(page)))
    case .pending(let version):
      menu.addItem(
        item(L10n.format(.menuUpdateAvailable, version), id: "update", command: .checkForUpdates))
    }
    menu.addItem(item(L10n.text(.menuSettings), id: "settings", command: .openSettings, key: ","))
    menu.addItem(item(L10n.text(.menuQuit), id: "quit", command: .quit, key: "q"))
    return menu
  }

  /// App and Docker rows, with two or more rows of one project under a group header (8.3).
  private func appendGrouped(
    _ entries: [ServerEntry], to menu: NSMenu, state: MenuState, dockerUnavailable: Bool = false
  ) {
    for position in MenuGroups.group(entries) {
      switch position {
      case .single(let entry):
        append([entry], to: menu, state: state, dockerUnavailable: dockerUnavailable)
      case .group(let key, let name, let branch, let rows):
        appendGroupHeader(
          key: key, name: name, branch: branch, rows: rows, to: menu, state: state,
          dockerUnavailable: dockerUnavailable)
        append(rows, to: menu, state: state, dockerUnavailable: dockerUnavailable, indent: 1)
      }
    }
  }

  private func appendGroupHeader(
    key: String, name: String, branch: String?, rows: [ServerEntry], to menu: NSMenu,
    state: MenuState, dockerUnavailable: Bool
  ) {
    let docker = rows.first?.section == .docker
    var text = name
    var gray: NSRange?
    if let branch {
      let label = " · " + Self.shortBranch(branch)
      gray = NSRange(location: (text as NSString).length, length: (label as NSString).length)
      text += label
    }
    text += "\t" + L10n.format(.groupCount, rows.count)
    let id = "group:" + key
    let header = item(text, id: id)
    header.attributedTitle = attributed(text, gray: gray)
    header.isEnabled = true
    let stoppable =
      dockerUnavailable
      ? []
      : rows.filter {
        $0.canTerminate && !state.stopping.contains($0.id)
      }
    let command = MenuCommand.stopAll(stoppable.map(ref), name: name)
    let submenu = NSMenu()
    submenu.autoenablesItems = false
    if docker {
      submenu.addItem(
        item(L10n.text(.subShowComposeFolder), id: "compose", command: .revealInFinder(key)))
    } else {
      submenu.addItem(
        item(L10n.text(.subShowInFinder), id: "finder", command: .revealInFinder(key)))
      submenu.addItem(
        item(L10n.text(.subOpenInTerminal), id: "terminal", command: .openInTerminal(key)))
    }
    if rows.contains(where: \.canTerminate) {
      separator(submenu, id: "stop.separator")
      let title = L10n.format(.groupStopAll, stoppable.count)
      let stop = item(title, id: "stopAll", command: command)
      stop.isEnabled = !stoppable.isEmpty
      // Same rule as a row's stop item: red only while enabled, so disabled stays plain gray.
      if stop.isEnabled {
        stop.attributedTitle = NSAttributedString(
          string: title,
          attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.menuFont(ofSize: 0)])
      }
      submenu.addItem(stop)
    }
    header.submenu = submenu
    menu.addItem(header)
    if !stoppable.isEmpty {
      let alternate = item(
        L10n.format(.rowStopGroup, name, stoppable.count), id: id + ".alternate", command: command)
      alternate.isAlternate = true
      alternate.keyEquivalentModifierMask = .option
      alternate.attributedTitle = Self.stopRowTitle(
        alternate.title, template: L10n.text(.rowStopGroup))
      menu.addItem(alternate)
    }
  }

  private func append(
    _ entries: [ServerEntry], to menu: NSMenu, state: MenuState, dockerUnavailable: Bool = false,
    indent: Int = 0
  ) {
    for entry in entries {
      let stopping = state.stopping.contains(entry.id)
      let system = entry.section == .system
      let docker = entry.section == .docker
      let title = displayTitle(entry)
      var text = "\(entry.primary.port)  \(title)"
      var branch: NSRange?
      // Inside a group the header carries the branch, shared by every row of that root.
      if !system, !docker, indent == 0, let name = entry.branch {
        let label = " · " + Self.shortBranch(name)
        branch = NSRange(location: (text as NSString).length, length: (label as NSString).length)
        text += label
      }
      var suffix: String?
      if entry.isLongRunning, let startedAt = entry.startedAt {
        suffix =
          " · "
          + L10n.format(.rowLongRunning, DurationText.short(now().timeIntervalSince(startedAt)))
        text += suffix!
      }
      if stopping { text += " · " + L10n.text(.rowStopping) }
      if !system, let tool = entry.tool { text += "\t" + tool }
      let row = item(text, id: entry.id)
      row.attributedTitle = attributed(text, orangeSuffix: suffix, gray: branch)
      let dot: StatusDot =
        system ? .system : docker ? .docker : entry.isLongRunning ? .longRunning : .running
      row.image = dot.image()
      row.isEnabled = true
      row.indentationLevel = indent
      row.submenu = submenu(entry, stopping: stopping, dockerUnavailable: dockerUnavailable)
      menu.addItem(row)
      if entry.canTerminate && !system && !stopping && !dockerUnavailable {
        let alternate = item(
          L10n.format(.rowStop, Int(entry.primary.port), title), id: entry.id + ".alternate",
          command: .stop(ref(entry)))
        alternate.isAlternate = true
        alternate.keyEquivalentModifierMask = .option
        alternate.attributedTitle = Self.stopRowTitle(alternate.title)
        alternate.indentationLevel = indent
        menu.addItem(alternate)
      }
    }
  }

  private func submenu(_ entry: ServerEntry, stopping: Bool, dockerUnavailable: Bool) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    if entry.section == .system {
      if entry.isAirPlay {
        menu.addItem(item(L10n.text(.systemAirplayHint), id: "hint"))
      } else {
        menu.addItem(
          item(
            L10n.text(.subCopyAddress), id: "copy",
            command: .copy("localhost:\(entry.primary.port)")))
      }
      return menu
    }
    let docker = entry.section == .docker
    if !docker && entry.primary.exposure == .network {
      let network = item(L10n.text(.exposureNetwork), id: "network")
      network.attributedTitle = NSAttributedString(
        string: network.title,
        attributes: [
          .foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.menuFont(ofSize: 0),
        ])
      menu.addItem(network)
      separator(menu, id: "network.separator")
    }
    let address = "localhost:\(entry.primary.port)"
    if entry.likelyHTTP {
      let open = item(
        L10n.text(.subOpenInBrowser) + "\t" + address, id: "browser",
        command: .openInBrowser(URL(string: "http://" + address)!))
      open.attributedTitle = attributed(open.title)
      menu.addItem(open)
    } else {
      menu.addItem(item(L10n.text(.subCopyAddress), id: "copy", command: .copy(address)))
    }
    if !docker, let directory = entry.directory {
      menu.addItem(
        item(L10n.text(.subShowInFinder), id: "finder", command: .revealInFinder(directory)))
      menu.addItem(
        item(L10n.text(.subOpenInTerminal), id: "terminal", command: .openInTerminal(directory)))
    }
    if entry.likelyHTTP {
      menu.addItem(item(L10n.text(.subCopyAddress), id: "copy", command: .copy(address)))
    }
    if docker, let directory = entry.directory {
      menu.addItem(
        item(L10n.text(.subShowComposeFolder), id: "compose", command: .revealInFinder(directory)))
    }
    if !docker && !entry.extras.isEmpty {
      separator(menu, id: "extras.separator")
      for extra in entry.extras {
        let role: String
        switch extra.role {
        case .debugger: role = L10n.text(.roleDebugger)
        case .liveReload: role = L10n.text(.roleLiveReload)
        case .inspector: role = L10n.text(.roleInspector)
        case nil: role = ""
        }
        menu.addItem(
          item(
            "\(extra.port)  \(role)", id: "extra.\(extra.port)",
            command: .copy("localhost:\(extra.port)")))
      }
    }
    // Container runtimes stay unstoppable even when shown, so they get no stop item at all.
    // Other apps of this user can be stopped like any server.
    if entry.section == .hidden(.otherApp) && !entry.canTerminate { return menu }
    separator(menu, id: "stop.separator")
    let stopTitle: String
    switch entry.target {
    case .process(let pid, _): stopTitle = L10n.format(.subStopWithPID, pid)
    case .container: stopTitle = L10n.text(.subStopContainer)
    }
    let stop = item(stopTitle, id: "stop", command: .stop(ref(entry)))
    stop.isEnabled = entry.canTerminate && !stopping && !dockerUnavailable
    // A red attributed title only fades to pink when disabled, so keep the plain title then and
    // let AppKit draw the standard gray disabled text.
    if !docker && stop.isEnabled {
      stop.attributedTitle = NSAttributedString(
        string: stopTitle,
        attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.menuFont(ofSize: 0)])
    }
    menu.addItem(stop)
    return menu
  }

  private func displayTitle(_ entry: ServerEntry) -> String {
    entry.isAirPlay ? L10n.text(.systemAirplay) : entry.title
  }

  /// The Option row with only the stop word ("Stop", "종료", "終了", "退出") in red, so the
  /// destructive action stands out while the port and name read as usual. The word is the text
  /// before the first format specifier of `row.stop`, minus the " · " separator.
  static func stopRowTitle(
    _ title: String, template: String = L10n.text(.rowStop)
  ) -> NSAttributedString {
    let font = NSFont.menuFont(ofSize: 0)
    let text = NSMutableAttributedString(string: title, attributes: [.font: font])
    let lead = template.components(separatedBy: "%").first ?? ""
    let word = lead.trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
    if !word.isEmpty, title.hasPrefix(word) {
      text.addAttribute(
        .foregroundColor, value: NSColor.systemRed,
        range: NSRange(location: 0, length: (word as NSString).length))
    }
    return text
  }

  private func ref(_ entry: ServerEntry) -> EntryRef {
    EntryRef(id: entry.id, target: entry.target, title: entry.title, port: entry.primary.port)
  }

  /// Branch names past 24 characters are cut to 23 and an ellipsis so the menu does not widen.
  static func shortBranch(_ name: String) -> String {
    name.count > 24 ? String(name.prefix(23)) + "…" : name
  }

  private func attributed(_ text: String, orangeSuffix: String? = nil, gray: NSRange? = nil)
    -> NSAttributedString
  {
    let paragraph = NSMutableParagraphStyle()
    paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 320)]
    let title = NSMutableAttributedString(
      string: text, attributes: [.font: NSFont.menuFont(ofSize: 0), .paragraphStyle: paragraph])
    if let gray {
      title.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: gray)
    }
    if let orangeSuffix {
      title.addAttribute(
        .foregroundColor, value: NSColor.systemOrange,
        range: (text as NSString).range(of: orangeSuffix, options: .backwards))
    }
    return title
  }

  private func separator(_ menu: NSMenu, id: String) {
    let separator = NSMenuItem.separator()
    separator.identifier = NSUserInterfaceItemIdentifier(id)
    menu.addItem(separator)
  }

  private func item(_ title: String, id: String, command: MenuCommand? = nil, key: String = "")
    -> NSMenuItem
  {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: key)
    item.identifier = NSUserInterfaceItemIdentifier(id)
    item.isEnabled = command != nil
    if let command {
      item.representedObject = CommandBox(command)
      item.target = self
      item.action = #selector(itemChosen(_:))
    }
    return item
  }

  @objc private func itemChosen(_ sender: NSMenuItem) {
    guard sender.isEnabled, let box = sender.representedObject as? CommandBox else { return }
    handler.perform(box.command)
  }
}
