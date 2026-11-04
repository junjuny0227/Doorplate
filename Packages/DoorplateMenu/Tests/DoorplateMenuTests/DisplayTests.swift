import DoorplateCore
import Foundation
import Testing

@testable import DoorplateMenu

struct DisplayTests {
  @Test(
    arguments: [
      (59.0, "1m"), (40.0 * 60, "40m"), (5.0 * 3600 + 59 * 60, "5h"),
      (3.0 * 86400 + 3600, "3d"), (0, "1m"), (-60, "1m"),
      (3600, "1h"), (86400, "1d"),
    ] as [(TimeInterval, String)])
  func durationBuckets(interval: TimeInterval, expected: String) {
    #expect(DurationText.short(interval) == expected)
  }

  @Test(arguments: [
    ("/Users/dev/repot", "~/repot"), ("/Users/dev", "~"),
    ("/Users/devx/a", "/Users/devx/a"), ("/opt/a", "/opt/a"),
  ])
  func abbreviatesHome(path: String, expected: String) {
    #expect(PathText.abbreviated(path, home: "/Users/dev") == expected)
  }

  @Test func badgeHiddenWhenZero() {
    #expect(StatusBadge.make(nil).text == "")
    #expect(!StatusBadge.make(nil).showsDot)
    var snapshot = Snapshot.empty(at: Date(timeIntervalSince1970: 0))
    #expect(StatusBadge.make(ScanOutcome(snapshot: snapshot, failedAt: nil)).text == "")
    snapshot.badgeCount = 3
    snapshot.hasLongRunning = true
    let badge = StatusBadge.make(ScanOutcome(snapshot: snapshot, failedAt: nil))
    #expect(badge.text == "3")
    #expect(badge.showsDot)
    snapshot.badgeCount = 0
    #expect(StatusBadge.make(ScanOutcome(snapshot: snapshot, failedAt: nil)).showsDot)
  }
}
