import Foundation

public struct ScanFixture: Sendable, Equatable, Codable {
  public var now: Date
  public var home: String
  public var currentUID: UInt32
  public var settings: SnapshotSettings
  public var listeners: [Listener]
  public var processes: [ProcessRecord]
  public var files: [String: String]
  public var denied: [String]
  public var docker: Docker
  public init(
    now: Date, home: String, currentUID: UInt32, settings: SnapshotSettings, listeners: [Listener],
    processes: [ProcessRecord], files: [String: String], denied: [String] = [], docker: Docker
  ) {
    self.now = now
    self.home = home
    self.currentUID = currentUID
    self.settings = settings
    self.listeners = listeners
    self.processes = processes
    self.files = files
    self.denied = denied
    self.docker = docker
  }
  public struct Docker: Sendable, Equatable, Codable {
    public var status: DockerStatus
    public var containers: [Container]?

    public init(status: DockerStatus, containers: [Container]? = nil) {
      self.status = status
      self.containers = status == .ok ? (containers ?? []) : nil
    }
  }

  private enum CodingKeys: String, CodingKey {
    case now, home, currentUID, settings, listeners, processes, files, denied, docker
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    now = try values.decode(Date.self, forKey: .now)
    home = try values.decode(String.self, forKey: .home)
    currentUID = try values.decode(UInt32.self, forKey: .currentUID)
    settings = try values.decode(SnapshotSettings.self, forKey: .settings)
    listeners = try values.decode([Listener].self, forKey: .listeners)
    processes = try values.decode([ProcessRecord].self, forKey: .processes)
    files = try values.decode([String: String].self, forKey: .files)
    denied = try values.decodeIfPresent([String].self, forKey: .denied) ?? []
    docker = try values.decode(Docker.self, forKey: .docker)
  }
}
