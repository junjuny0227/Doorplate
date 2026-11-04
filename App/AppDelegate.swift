import AppKit
import DoorplateCore
import DoorplateMenu

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusController: StatusItemController?
  private var performer: ActionPerformer?
  private var stopCoordinator: StopCoordinator?

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
      openSettings: {}, checkForUpdates: {}, quit: { NSApp.terminate(nil) })
    self.performer = performer
    let builder = MenuBuilder(handler: performer, home: home, now: { Date() })
    let controller = StatusItemController(
      scanner: scanner, builder: builder, settings: { SnapshotSettings() })
    statusController = controller
    controller.start()
  }
}
