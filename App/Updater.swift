import Combine
import DoorplateMenu
import Sparkle
import os

@MainActor final class Updater: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
  private let settings: SettingsStore
  private let onChange: (UpdateMenuItem) -> Void
  private let logger = Logger(subsystem: "io.github.junjuny0227.doorplate", category: "update")
  private var subscriptions: Set<AnyCancellable> = []
  private lazy var controller = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

  init(settings: SettingsStore, onChange: @escaping (UpdateMenuItem) -> Void) {
    self.settings = settings
    self.onChange = onChange
    super.init()

    // Apply Doorplate's saved preference before Sparkle's next-runloop scheduling.
    let updater = controller.updater
    if updater.automaticallyChecksForUpdates != settings.checkForUpdates {
      updater.automaticallyChecksForUpdates = settings.checkForUpdates
    }
    settings.$checkForUpdates.removeDuplicates().sink { [weak updater] enabled in
      guard let updater, updater.automaticallyChecksForUpdates != enabled else { return }
      updater.automaticallyChecksForUpdates = enabled
    }.store(in: &subscriptions)
    // Sparkle can also change the preference through its own UI. Avoid feedback writes.
    updater.publisher(for: \.automaticallyChecksForUpdates).removeDuplicates().sink {
      [weak settings] enabled in
      guard let settings, settings.checkForUpdates != enabled else { return }
      settings.checkForUpdates = enabled
    }.store(in: &subscriptions)
    onChange(.checkForUpdates)
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }

  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    immediateFocus
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
  ) {
    guard !handleShowingUpdate, !state.userInitiated else { return }
    logger.info("Scheduled update available: \(update.displayVersionString, privacy: .public)")
    onChange(.pending(version: update.displayVersionString))
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    onChange(.checkForUpdates)
  }

  func standardUserDriverWillFinishUpdateSession() {
    onChange(.checkForUpdates)
  }
}
