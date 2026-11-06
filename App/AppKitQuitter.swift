import AppKit
import DoorplateCore

/// Quits regular macOS apps (Steam, Spotify, …) the way ⌘Q does, so they can save their state.
/// Background processes (dev servers, agents, daemons) are not regular apps and are left to
/// Terminator's SIGTERM.
struct AppKitQuitter: AppQuitter {
  func requestQuit(pid: Int32) async -> Bool {
    await MainActor.run {
      guard let app = NSRunningApplication(processIdentifier: pid),
        app.activationPolicy == .regular
      else { return false }
      return app.terminate()
    }
  }
}
