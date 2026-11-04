import Foundation

public enum SnapshotBuilder {
  public static func build(
    _ entries: [ServerEntry], dockerStatus: DockerStatus, settings: SnapshotSettings, now: Date
  ) -> Snapshot {
    var apps: [ServerEntry] = []
    var system: [ServerEntry] = []
    var docker: [ServerEntry] = []
    var hidden: [ServerEntry] = []

    for var entry in entries {
      entry.isLongRunning =
        entry.startedAt.map {
          now.timeIntervalSince($0) > settings.longRunningThreshold
        } ?? false

      switch entry.section {
      case .app:
        apps.append(entry)
      case .system:
        system.append(entry)
      case .docker:
        docker.append(entry)
      case .hidden(.devTool) where settings.showDevTools:
        apps.append(entry)
      case .hidden(.otherApp) where settings.showOtherApps:
        apps.append(entry)
      case .hidden:
        hidden.append(entry)
      }
    }

    func ordered(_ entries: [ServerEntry]) -> [ServerEntry] {
      entries.sorted {
        if $0.primary.port != $1.primary.port { return $0.primary.port < $1.primary.port }
        return $0.id < $1.id
      }
    }

    apps = ordered(apps)
    system = ordered(system)
    docker = ordered(docker)
    hidden = ordered(hidden)

    return Snapshot(
      apps: apps, system: system, docker: docker, hidden: hidden, dockerStatus: dockerStatus,
      badgeCount: apps.count + docker.count,
      hasLongRunning: apps.contains(where: \.isLongRunning)
        || docker.contains(where: \.isLongRunning),
      scannedAt: now)
  }
}
