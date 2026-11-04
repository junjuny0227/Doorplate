import DoorplateCore
import Foundation

let menuNow = Date(timeIntervalSince1970: 1_800_000_000)

func entry(
  port: UInt16 = 5173, title: String = "@repot/desktop", tool: String? = "vite",
  section: Section = .app, id: String = "pid:101", pid: Int32 = 101,
  startedAt: Date = menuNow.addingTimeInterval(-2400), isLongRunning: Bool = false,
  exposure: Exposure = .loopback, directory: String? = "/Users/dev/repot/apps/desktop",
  root: String? = "/Users/dev/repot", extras: [PortBinding] = [],
  likelyHTTP: Bool = true, canTerminate: Bool = true
) -> ServerEntry {
  ServerEntry(
    id: id,
    target: section == .docker ? .container(id: id) : .process(pid: pid, startedAt: startedAt),
    section: section, title: title, tool: tool, primary: .init(port: port, exposure: exposure),
    extras: extras, directory: directory, repositoryRoot: root, startedAt: startedAt,
    isLongRunning: isLongRunning, likelyHTTP: likelyHTTP, canTerminate: canTerminate)
}

func outcome(
  apps: [ServerEntry] = [], system: [ServerEntry] = [], docker: [ServerEntry] = [],
  hidden: [ServerEntry] = [], dockerStatus: DockerStatus = .absent, failedAt: Date? = nil
) -> ScanOutcome {
  ScanOutcome(
    snapshot: Snapshot(
      apps: apps, system: system, docker: docker, hidden: hidden, dockerStatus: dockerStatus,
      badgeCount: apps.count + docker.count,
      hasLongRunning: (apps + docker).contains(where: \.isLongRunning), scannedAt: menuNow),
    failedAt: failedAt)
}
