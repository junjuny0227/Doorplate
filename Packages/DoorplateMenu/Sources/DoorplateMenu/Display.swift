import DoorplateCore
import Foundation

public enum DurationText {
  public static func short(_ interval: TimeInterval) -> String {
    if interval < 3600 {
      return L10n.format(.durationMinutes, max(1, Int(interval / 60)))
    }
    if interval < 86400 {
      return L10n.format(.durationHours, Int(interval / 3600))
    }
    return L10n.format(.durationDays, Int(interval / 86400))
  }
}

public enum PathText {
  public static func abbreviated(_ path: String, home: String) -> String {
    if path == home { return "~" }
    if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
    return path
  }
}

public struct StatusBadge: Equatable {
  public var text: String
  public var showsDot: Bool

  public static func make(_ outcome: ScanOutcome?) -> StatusBadge {
    let count = outcome?.snapshot.badgeCount ?? 0
    return StatusBadge(
      text: count == 0 ? "" : "\(count)", showsDot: outcome?.snapshot.hasLongRunning ?? false)
  }
}
