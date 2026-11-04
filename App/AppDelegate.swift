import AppKit
import DoorplateCore
import DoorplateMenu

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusController: StatusItemController?
  private var performer: ActionPerformer?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let home = NSHomeDirectory()
    let scanner = DoorplateCore.Scanner(
      processes: LibprocProcessSource(), files: LocalFileProbe(),
      docker: UnixSocketDockerSource(
        candidatePaths: UnixSocketDockerSource.defaultPaths(home: home)),
      currentUID: getuid(), now: { Date() })
    let performer = ActionPerformer(
      openSettings: {}, checkForUpdates: {}, quit: { NSApp.terminate(nil) })
    self.performer = performer
    let builder = MenuBuilder(handler: performer, home: home, now: { Date() })
    let controller = StatusItemController(
      scanner: scanner, builder: builder, settings: { SnapshotSettings() })
    statusController = controller
    controller.start()
  }
}
