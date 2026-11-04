import DoorplateCore
import Foundation

public struct StatusBadge: Equatable {
  public var text: String
  public var showsDot: Bool

  public static func make(_ outcome: ScanOutcome?) -> StatusBadge {
    let count = outcome?.snapshot.badgeCount ?? 0
    return StatusBadge(text: count == 0 ? "" : "\(count)", showsDot: outcome?.snapshot.hasLongRunning ?? false)
  }
}
