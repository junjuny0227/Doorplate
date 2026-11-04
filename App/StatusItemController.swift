import AppKit
import DoorplateCore
import DoorplateMenu
import os

@MainActor final class StatusItemController: NSObject, NSMenuDelegate {
  private let scanner: DoorplateCore.Scanner
  private let builder: MenuBuilder
  private let settings: () -> SnapshotSettings
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let signpostLog = OSLog(subsystem: "io.github.junjuny0227.doorplate", category: "menu")
  private var timer: Timer?
  private var latest: ScanOutcome?
  private var menuIsOpen = false
  private var displayedBadge: StatusBadge?

  var state = MenuState() {
    didSet {
      if menuIsOpen, state != oldValue {
        builder.refresh(menu, outcome: latest, state: state)
      }
    }
  }

  init(
    scanner: DoorplateCore.Scanner, builder: MenuBuilder, settings: @escaping () -> SnapshotSettings
  ) {
    self.scanner = scanner
    self.builder = builder
    self.settings = settings
    super.init()
    menu.delegate = self
    statusItem.menu = menu
    statusItem.button?.imagePosition = .imageLeading
    statusItem.button?.setAccessibilityLabel("Doorplate")
    updateBadge()
  }

  func start() {
    guard timer == nil else { return }
    let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
      // Registered only on the main run loop, including event tracking.
      MainActor.assumeIsolated { self?.refreshNow() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
    refreshNow()
  }

  func refreshNow() {
    let settings = settings()
    // DoorplateCore.Scanner's actor executor owns all system queries and project-file reads.
    // Only the completed Sendable outcome returns to the main actor.
    Task { [weak self, scanner] in
      guard let outcome = await scanner.scan(settings: settings), let self else { return }
      let changed = latest != outcome
      latest = outcome
      updateBadge()
      if menuIsOpen, changed {
        builder.refresh(menu, outcome: latest, state: state)
      }
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    let id = OSSignpostID(log: signpostLog)
    os_signpost(.begin, log: signpostLog, name: "menuNeedsUpdate", signpostID: id)
    defer { os_signpost(.end, log: signpostLog, name: "menuNeedsUpdate", signpostID: id) }
    builder.populate(menu, outcome: latest, state: state)
    refreshNow()
  }

  func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
  func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

  private func updateBadge() {
    let badge = StatusBadge.make(latest)
    guard displayedBadge != badge else { return }
    displayedBadge = badge
    statusItem.button?.title = badge.text
    statusItem.button?.image = statusImage(showsDot: badge.showsDot)
  }

  private func statusImage(showsDot: Bool) -> NSImage? {
    guard
      let symbol = NSImage(systemSymbolName: "door.left.hand.closed", accessibilityDescription: nil)
    else { return nil }
    symbol.size = NSSize(width: 18, height: 18)
    symbol.isTemplate = true
    guard showsDot else { return symbol }
    let image = NSImage(size: NSSize(width: 20, height: 18))
    image.lockFocus()
    let coloredSymbol =
      symbol.withSymbolConfiguration(.init(paletteColors: [.labelColor])) ?? symbol
    coloredSymbol.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
    NSColor.systemOrange.setFill()
    NSBezierPath(ovalIn: NSRect(x: 15, y: 0, width: 5, height: 5)).fill()
    image.unlockFocus()
    image.isTemplate = false
    return image
  }
}
