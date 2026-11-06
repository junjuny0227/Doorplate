import Foundation
import Testing

@testable import DoorplateCore

private func entry(
  _ id: String, _ port: UInt16, _ section: Section, startedAt: Date? = nil
) -> ServerEntry {
  ServerEntry(
    id: id, target: .process(pid: 1, startedAt: startedAt), section: section, title: id,
    primary: PortBinding(port: port, exposure: .loopback), startedAt: startedAt,
    likelyHTTP: true, canTerminate: false)
}

@Suite struct SnapshotBuilderTests {
  @Test func placesSectionsInPortOrder() {
    let result = SnapshotBuilder.build(
      [
        entry("app-high", 8080, .app), entry("app-low", 3000, .app),
        entry("airplay", 5000, .system), entry("container", 5432, .docker),
        entry("hidden", 63342, .hidden(.devTool)),
      ], dockerStatus: .ok, settings: .init(showSystemPorts: true),
      now: Date(timeIntervalSince1970: 0))
    #expect(result.apps.map(\.primary.port) == [3000, 8080])
    #expect(result.system.map(\.primary.port) == [5000])
    #expect(result.docker.map(\.primary.port) == [5432])
    #expect(result.hidden.map(\.primary.port) == [63342])
  }

  @Test func settingsRevealHiddenEntries() {
    let result = SnapshotBuilder.build(
      [
        entry("gradle", 5005, .hidden(.devTool)), entry("spotify", 6000, .hidden(.otherApp)),
      ], dockerStatus: .absent, settings: .init(showDevTools: true, showOtherApps: true),
      now: Date())
    #expect(result.apps.map(\.id) == ["gradle", "spotify"])
    #expect(result.hidden.isEmpty)
  }

  @Test(arguments: [false, true], [false, true])
  func systemVisibilityIsIndependentOfOtherApps(showSystemPorts: Bool, showOtherApps: Bool) {
    let result = SnapshotBuilder.build(
      [
        entry("airplay", 5000, .system), entry("rapportd", 49152, .system),
        entry("spotify", 6000, .hidden(.otherApp)),
        entry("gradle", 63342, .hidden(.devTool)),
      ], dockerStatus: .absent,
      settings: .init(showOtherApps: showOtherApps, showSystemPorts: showSystemPorts), now: Date())
    #expect(result.system.map(\.id) == (showSystemPorts ? ["airplay", "rapportd"] : []))
    #expect(result.apps.map(\.id) == (showOtherApps ? ["spotify"] : []))
    #expect(result.hidden.filter { $0.section == .system }.count == (showSystemPorts ? 0 : 2))
    #expect(result.hidden.count == 1 + (showSystemPorts ? 0 : 2) + (showOtherApps ? 0 : 1))
    #expect(result.badgeCount == (showOtherApps ? 1 : 0))
  }

  @Test(arguments: [(25.0, true), (23.0, false), (Double.nan, false)])
  func longRunningThreshold(hoursAgo: Double, expected: Bool) {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let startedAt = hoursAgo.isNaN ? nil : now.addingTimeInterval(-hoursAgo * 3600)
    let result = SnapshotBuilder.build(
      [entry("app", 8080, .app, startedAt: startedAt)],
      dockerStatus: .ok, settings: .init(), now: now)
    #expect(result.apps[0].isLongRunning == expected)
  }

  @Test(arguments: [false, true])
  func badgeCountExcludesSystemAndHidden(showSystemPorts: Bool) {
    let result = SnapshotBuilder.build(
      [
        entry("airplay", 5000, .system), entry("app1", 3000, .app), entry("app2", 8080, .app),
        entry("docker", 5432, .docker), entry("hidden", 63342, .hidden(.devTool)),
      ], dockerStatus: .ok, settings: .init(showSystemPorts: showSystemPorts), now: Date())
    #expect(result.badgeCount == 3)
  }

  @Test(arguments: [false, true])
  func hasLongRunningIgnoresHiddenAndSystem(showSystemPorts: Bool) {
    let old = Date(timeIntervalSince1970: 0)
    let result = SnapshotBuilder.build(
      [
        entry("hidden", 1, .hidden(.devTool), startedAt: old),
        entry("system", 2, .system, startedAt: old),
      ], dockerStatus: .ok, settings: .init(showSystemPorts: showSystemPorts),
      now: Date(timeIntervalSince1970: 200_000))
    #expect(!result.hasLongRunning)
    #expect(
      (result.system + result.hidden).filter { $0.section == .system }.allSatisfy {
        !$0.isLongRunning
      })
  }

  @Test func emptyInput() {
    let result = SnapshotBuilder.build(
      [], dockerStatus: .notResponding, settings: .init(), now: Date())
    #expect(result.badgeCount == 0)
    #expect(result.dockerStatus == .notResponding)
  }
}
