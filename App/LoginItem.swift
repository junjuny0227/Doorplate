import AppKit
import Combine
import DoorplateMenu
import ServiceManagement
import SwiftUI

@MainActor private final class LoginQuestionWindowController: NSWindowController {
  init(onEnable: @escaping () -> Void) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 380, height: 150),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = L10n.text(.firstLaunchTitle)
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.contentViewController = NSHostingController(
      rootView: LoginQuestionView { [weak self] enable in
        self?.close()
        if enable { onEnable() }
      })
    window.center()
  }

  required init?(coder: NSCoder) { nil }

  func open() {
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}

private struct LoginQuestionView: View {
  let onAnswer: (Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(L10n.text(.firstLaunchTitle))
        .font(.headline)
      HStack {
        Spacer()
        Button(L10n.text(.firstLaunchNo)) { onAnswer(false) }
          .keyboardShortcut(.cancelAction)
        Button(L10n.text(.firstLaunchYes)) { onAnswer(true) }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 380)
  }
}

@MainActor final class LoginItem: ObservableObject {
  @Published private(set) var isEnabled = false
  @Published private(set) var requiresApproval = false

  init() { refresh() }

  func refresh() {
    let status = SMAppService.mainApp.status
    isEnabled = status == .enabled
    requiresApproval = status == .requiresApproval
  }

  func setEnabled(_ enabled: Bool) {
    refresh()
    guard enabled != isEnabled else { return }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      refresh()
    } catch {
      refresh()
      NSSound.beep()
      let alert = NSAlert()
      alert.messageText = L10n.format(.alertLoginFailed, error.localizedDescription)
      alert.addButton(withTitle: L10n.text(.alertOK))
      NSApp.activate(ignoringOtherApps: true)
      alert.runModal()
    }
  }

  func askOnFirstLaunch(settings: SettingsStore) {
    guard !settings.hasAskedOpenAtLogin else { return }
    // Persist before presenting: a nested app event must not present a second question.
    settings.hasAskedOpenAtLogin = true
    let alert = NSAlert()
    alert.messageText = L10n.text(.firstLaunchTitle)
    alert.addButton(withTitle: L10n.text(.firstLaunchYes))
    alert.addButton(withTitle: L10n.text(.firstLaunchNo))
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn { setEnabled(true) }
  }
}
