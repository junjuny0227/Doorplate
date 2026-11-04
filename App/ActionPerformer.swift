import DoorplateMenu

@MainActor final class ActionPerformer: MenuCommandHandler {
  private let openSettings: () -> Void
  private let checkForUpdates: () -> Void
  private let quit: () -> Void

  init(
    openSettings: @escaping () -> Void, checkForUpdates: @escaping () -> Void,
    quit: @escaping () -> Void
  ) {
    self.openSettings = openSettings
    self.checkForUpdates = checkForUpdates
    self.quit = quit
  }

  func perform(_ command: MenuCommand) {
    switch command {
    case .openSettings: openSettings()
    case .checkForUpdates: checkForUpdates()
    case .quit: quit()
    case .openInBrowser, .revealInFinder, .openInTerminal, .copy, .stop, .openUpdatePage:
      // Task 4 connects workspace actions and the stop coordinator.
      break
    }
  }
}
