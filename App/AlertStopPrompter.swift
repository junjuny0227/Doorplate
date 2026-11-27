import AppKit
import DoorplateMenu

@MainActor final class AlertStopPrompter: StopPrompter {
  func askToForceStop(title: String) async -> Bool {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = L10n.format(.alertStillRunning, title)
    let force = alert.addButton(withTitle: L10n.text(.alertForceStop))
    let wait = alert.addButton(withTitle: L10n.text(.alertKeepWaiting))
    // Return must not accidentally escalate a graceful stop to SIGKILL.
    force.keyEquivalent = ""
    wait.keyEquivalent = "\r"
    NSApp.activate()
    return alert.runModal() == .alertFirstButtonReturn
  }

  func confirmStopAll(name: String, servers: [String]) async -> Bool {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = L10n.format(.alertConfirmStopAll, name, servers.count)
    alert.informativeText = servers.joined(separator: "\n")
    let stop = alert.addButton(withTitle: L10n.text(.alertStop))
    let cancel = alert.addButton(withTitle: L10n.text(.alertCancel))
    stop.hasDestructiveAction = true
    // Return cancels, like the force-stop prompt: one key press must not stop several servers.
    stop.keyEquivalent = ""
    cancel.keyEquivalent = "\r"
    NSApp.activate()
    return alert.runModal() == .alertFirstButtonReturn
  }

  func report(_ message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = message
    alert.addButton(withTitle: L10n.text(.alertOK))
    NSApp.activate()
    alert.runModal()
  }

  func signalAlreadyGone() {
    NSSound.beep()
  }
}
