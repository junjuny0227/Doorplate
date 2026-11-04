import AppKit
import DoorplateMenu
import SwiftUI

@MainActor final class SettingsWindowController: NSWindowController {
  init(settings: SettingsStore, loginItem: LoginItem, onChange: @escaping () -> Void) {
    let hosting = NSHostingController(
      rootView: SettingsView(settings: settings, loginItem: loginItem, onChange: onChange))
    let window = NSWindow(contentViewController: hosting)
    window.title = L10n.text(.settingsTitle)
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.center()
  }

  required init?(coder: NSCoder) { nil }

  func open() {
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}
