import Foundation

public enum DockerStatus: String, Sendable, Equatable, Codable { case absent, ok, notResponding }

public struct SnapshotSettings: Sendable, Equatable, Codable {
  public var longRunningThreshold: TimeInterval
  public var showDevTools: Bool
  public var showOtherApps: Bool
  public var showSystemPorts: Bool
  public init(
    longRunningThreshold: TimeInterval = 86_400, showDevTools: Bool = false,
    showOtherApps: Bool = false, showSystemPorts: Bool = false
  ) {
    self.longRunningThreshold = longRunningThreshold
    self.showDevTools = showDevTools
    self.showOtherApps = showOtherApps
    self.showSystemPorts = showSystemPorts
  }

  private enum CodingKeys: String, CodingKey {
    case longRunningThreshold, showDevTools, showOtherApps, showSystemPorts
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    longRunningThreshold = try values.decode(TimeInterval.self, forKey: .longRunningThreshold)
    showDevTools = try values.decode(Bool.self, forKey: .showDevTools)
    showOtherApps = try values.decode(Bool.self, forKey: .showOtherApps)
    // Fixtures captured before this setting existed use the new default too.
    showSystemPorts = try values.decodeIfPresent(Bool.self, forKey: .showSystemPorts) ?? false
  }
}

public struct Snapshot: Sendable, Equatable, Codable {
  public var apps: [ServerEntry]
  public var system: [ServerEntry]
  public var docker: [ServerEntry]
  public var hidden: [ServerEntry]
  public var dockerStatus: DockerStatus
  public var badgeCount: Int
  public var hasLongRunning: Bool
  public var scannedAt: Date
  public init(
    apps: [ServerEntry], system: [ServerEntry], docker: [ServerEntry], hidden: [ServerEntry],
    dockerStatus: DockerStatus, badgeCount: Int, hasLongRunning: Bool, scannedAt: Date
  ) {
    self.apps = apps
    self.system = system
    self.docker = docker
    self.hidden = hidden
    self.dockerStatus = dockerStatus
    self.badgeCount = badgeCount
    self.hasLongRunning = hasLongRunning
    self.scannedAt = scannedAt
  }
  public static func empty(at: Date) -> Snapshot {
    Snapshot(
      apps: [], system: [], docker: [], hidden: [], dockerStatus: .absent,
      badgeCount: 0, hasLongRunning: false, scannedAt: at)
  }
}
