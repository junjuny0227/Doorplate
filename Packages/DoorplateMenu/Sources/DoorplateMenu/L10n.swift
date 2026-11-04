import Foundation

public enum L10n {
  public static func text(_ key: Key) -> String {
    Bundle.module.localizedString(forKey: key.rawValue, value: nil, table: nil)
  }

  public static func format(_ key: Key, _ args: CVarArg...) -> String {
    // Ports and PIDs must never get thousands separators ("5,173"), so format without a locale.
    String(format: text(key), locale: nil, arguments: args)
  }

  public enum Key: String, CaseIterable {
    case headerRunning = "header.running"
    case headerFailed = "header.failed"
    case menuEmpty = "menu.empty"
    case menuDocker = "menu.docker"
    case menuDockerNotResponding = "menu.dockerNotResponding"
    case menuHidden = "menu.hidden"
    case menuSettings = "menu.settings"
    case menuQuit = "menu.quit"
    case menuCheckForUpdates = "menu.checkForUpdates"
    case menuUpdateAvailable = "menu.updateAvailable"
    case rowStop = "row.stop"
    case rowLongRunning = "row.longRunning"
    case rowStopping = "row.stopping"
    case subOpenInBrowser = "sub.openInBrowser"
    case subShowInFinder = "sub.showInFinder"
    case subShowComposeFolder = "sub.showComposeFolder"
    case subOpenInTerminal = "sub.openInTerminal"
    case subCopyAddress = "sub.copyAddress"
    case subStopWithPID = "sub.stopWithPID"
    case subStopContainer = "sub.stopContainer"
    case exposureNetwork = "exposure.network"
    case roleDebugger = "role.debugger"
    case roleLiveReload = "role.liveReload"
    case roleInspector = "role.inspector"
    case systemAirplay = "system.airplay"
    case systemAirplayHint = "system.airplayHint"
    case durationMinutes = "duration.minutes"
    case durationHours = "duration.hours"
    case durationDays = "duration.days"
    case alertOK = "alert.ok"
    case alertStillRunning = "alert.stillRunning"
    case alertForceStop = "alert.forceStop"
    case alertKeepWaiting = "alert.keepWaiting"
    case alertNotPermitted = "alert.notPermitted"
    case alertCouldNotStop = "alert.couldNotStop"
    case alertDockerFailed = "alert.dockerFailed"
    case alertOpenFailed = "alert.openFailed"
    case firstLaunchTitle = "firstLaunch.title"
    case firstLaunchYes = "firstLaunch.yes"
    case firstLaunchNo = "firstLaunch.no"
    case settingsOpenAtLogin = "settings.openAtLogin"
    case settingsLongRunning = "settings.longRunning"
    case settingsHours = "settings.hours"
    case settingsShowDevTools = "settings.showDevTools"
    case settingsShowOtherApps = "settings.showOtherApps"
    case settingsTerminal = "settings.terminal"
    case settingsAutoUpdate = "settings.autoUpdate"
    case settingsLoginRequiresApproval = "settings.loginRequiresApproval"
  }
}
