import AppKit
import DoorplateMenu

@MainActor final class ActionPerformer: MenuCommandHandler {
  private let coordinator: StopCoordinator
  private let prompter: any StopPrompter
  private let terminalBundleID: () -> String
  private let openSettings: () -> Void
  private let checkForUpdates: () -> Void
  private let quit: () -> Void

  init(
    coordinator: StopCoordinator, prompter: any StopPrompter,
    terminalBundleID: @escaping () -> String = { "com.apple.Terminal" },
    openSettings: @escaping () -> Void, checkForUpdates: @escaping () -> Void,
    quit: @escaping () -> Void
  ) {
    self.coordinator = coordinator
    self.prompter = prompter
    self.terminalBundleID = terminalBundleID
    self.openSettings = openSettings
    self.checkForUpdates = checkForUpdates
    self.quit = quit
  }

  func perform(_ command: MenuCommand) {
    switch command {
    case .openSettings: openSettings()
    case .checkForUpdates: checkForUpdates()
    case .quit: quit()
    case .openInBrowser(let url), .openUpdatePage(let url):
      if !NSWorkspace.shared.open(url) { reportOpenFailure(url.absoluteString) }
    case .revealInFinder(let path):
      guard FileManager.default.fileExists(atPath: path) else {
        reportOpenFailure(path)
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    case .openInTerminal(let path):
      openInTerminal(path)
    case .copy(let address):
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(address, forType: .string)
    case .stop(let ref):
      Task { await coordinator.stop(ref) }
    }
  }

  private func openInTerminal(_ path: String) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      reportOpenFailure(path)
      return
    }
    let application = TerminalApps.resolved(selected: terminalBundleID()) {
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
    }
    Task {
      do {
        _ = try await NSWorkspace.shared.open(
          [URL(fileURLWithPath: path, isDirectory: true)], withApplicationAt: application,
          configuration: .init())
      } catch {
        reportOpenFailure(path)
      }
    }
  }

  private func reportOpenFailure(_ destination: String) {
    NSSound.beep()
    prompter.report(L10n.format(.alertOpenFailed, destination))
  }
}
