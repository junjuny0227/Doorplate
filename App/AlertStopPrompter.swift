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
