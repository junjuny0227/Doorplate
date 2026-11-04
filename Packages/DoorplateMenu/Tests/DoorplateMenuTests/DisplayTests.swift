import DoorplateCore
import Foundation
import Testing

@testable import DoorplateMenu

struct DisplayTests {
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
