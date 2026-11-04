import AppKit
import DoorplateCore
import DoorplateMenu

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusController: StatusItemController?
  private var performer: ActionPerformer?
  private var stopCoordinator: StopCoordinator?
  private let settings = SettingsStore(defaults: .standard)
  private let loginItem = LoginItem()
  private var settingsController: SettingsWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let home = NSHomeDirectory()
    let docker = UnixSocketDockerSource(
      candidatePaths: UnixSocketDockerSource.defaultPaths(home: home))
    let scanner = DoorplateCore.Scanner(
      processes: LibprocProcessSource(), files: LocalFileProbe(), docker: docker,
      currentUID: getuid(), now: { Date() })
    let prompter = AlertStopPrompter()
    let coordinator = StopCoordinator(
      terminator: Terminator(signaler: PosixSignaler(), docker: docker), prompter: prompter,
      onChange: { [weak self] in
        guard let self, let controller = statusController, let coordinator = stopCoordinator else {
          return
        }
        controller.state.stopping = coordinator.stopping
        controller.refreshNow()
      })
    stopCoordinator = coordinator
    let performer = ActionPerformer(
      coordinator: coordinator, prompter: prompter,
      terminalBundleID: { [settings] in settings.terminalBundleID },
      openSettings: { [weak self] in self?.openSettings() },
      checkForUpdates: {}, quit: { NSApp.terminate(nil) })
    self.performer = performer
    let builder = MenuBuilder(handler: performer, home: home, now: { Date() })
    let controller = StatusItemController(
      scanner: scanner, builder: builder, settings: { [settings] in settings.snapshotSettings })
    statusController = controller
    controller.start()
    Task { @MainActor [weak self] in
      guard let self else { return }
      loginItem.askOnFirstLaunch(settings: settings)
    }
  }

  private func openSettings() {
    loginItem.refresh()
    if settingsController == nil {
      settingsController = SettingsWindowController(settings: settings, loginItem: loginItem) {
        [weak self] in self?.statusController?.refreshNow()
      }
    }
    settingsController?.open()
  }
}
