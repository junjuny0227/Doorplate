import AppKit
import Combine
import DoorplateMenu
import ServiceManagement

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
