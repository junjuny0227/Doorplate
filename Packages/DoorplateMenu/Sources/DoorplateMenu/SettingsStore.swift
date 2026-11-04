import Combine
import DoorplateCore
import Foundation

@MainActor public final class SettingsStore: ObservableObject {
  private enum Key {
    static let longRunningHours = "longRunningHours"
    static let showDevTools = "showDevTools"
    static let showOtherApps = "showOtherApps"
    static let terminalBundleID = "terminalBundleID"
    static let checkForUpdates = "checkForUpdates"
    static let askedOpenAtLogin = "askedOpenAtLogin"
  }

  private let defaults: UserDefaults

  public init(defaults: UserDefaults) {
    self.defaults = defaults
    let initialHours =
      defaults.object(forKey: Key.longRunningHours) == nil
      ? 24 : defaults.integer(forKey: Key.longRunningHours)
    longRunningHours = min(max(initialHours, 1), 168)
    showDevTools =
      defaults.object(forKey: Key.showDevTools) == nil
      ? false : defaults.bool(forKey: Key.showDevTools)
    showOtherApps =
      defaults.object(forKey: Key.showOtherApps) == nil
      ? false : defaults.bool(forKey: Key.showOtherApps)
    terminalBundleID = defaults.string(forKey: Key.terminalBundleID) ?? "com.apple.Terminal"
    checkForUpdates =
      defaults.object(forKey: Key.checkForUpdates) == nil
      ? true : defaults.bool(forKey: Key.checkForUpdates)
    defaults.set(longRunningHours, forKey: Key.longRunningHours)
    defaults.set(showDevTools, forKey: Key.showDevTools)
    defaults.set(showOtherApps, forKey: Key.showOtherApps)
    defaults.set(terminalBundleID, forKey: Key.terminalBundleID)
    defaults.set(checkForUpdates, forKey: Key.checkForUpdates)
    if defaults.object(forKey: Key.askedOpenAtLogin) == nil {
      defaults.set(false, forKey: Key.askedOpenAtLogin)
    }
  }

  @Published public var longRunningHours: Int {
    didSet {
      let clamped = min(max(longRunningHours, 1), 168)
      if clamped != longRunningHours {
        longRunningHours = clamped
        return
      }
      defaults.set(clamped, forKey: Key.longRunningHours)
    }
  }

  @Published public var showDevTools: Bool {
    didSet { defaults.set(showDevTools, forKey: Key.showDevTools) }
  }

  @Published public var showOtherApps: Bool {
    didSet { defaults.set(showOtherApps, forKey: Key.showOtherApps) }
  }

  @Published public var terminalBundleID: String {
    didSet { defaults.set(terminalBundleID, forKey: Key.terminalBundleID) }
  }

  @Published public var checkForUpdates: Bool {
    didSet { defaults.set(checkForUpdates, forKey: Key.checkForUpdates) }
  }

  public var hasAskedOpenAtLogin: Bool {
    get { defaults.bool(forKey: Key.askedOpenAtLogin) }
    set { defaults.set(newValue, forKey: Key.askedOpenAtLogin) }
  }

  public var snapshotSettings: SnapshotSettings {
    SnapshotSettings(
      longRunningThreshold: TimeInterval(longRunningHours) * 3_600,
      showDevTools: showDevTools,
      showOtherApps: showOtherApps)
  }
}
