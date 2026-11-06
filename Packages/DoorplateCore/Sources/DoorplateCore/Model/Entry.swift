import Foundation

public enum PortRole: String, Sendable, Equatable, Codable { case debugger, liveReload, inspector }
public enum HiddenReason: String, Sendable, Equatable, Codable { case devTool, otherApp }
public enum Section: Sendable, Equatable, Codable {
  case app, system, docker
  case hidden(HiddenReason)
}
public enum Target: Sendable, Equatable, Codable {
  case process(pid: Int32, startedAt: Date?)
  case container(id: String)
}

public struct PortBinding: Sendable, Equatable, Codable {
  public var port: UInt16
  public var exposure: Exposure
  public var role: PortRole?
  public init(port: UInt16, exposure: Exposure, role: PortRole? = nil) {
    self.port = port
    self.exposure = exposure
    self.role = role
  }

}

public struct ServerEntry: Sendable, Equatable, Codable {
  static let airPlayTool = "airplay"

  public var id: String
  public var target: Target
  public var section: Section
  public var title: String
  public var tool: String?
  public var image: String?
  public var primary: PortBinding
  public var extras: [PortBinding]
  public var directory: String?
  public var repositoryRoot: String?
  public var startedAt: Date?
  public var isLongRunning: Bool
  public var likelyHTTP: Bool
  public var canTerminate: Bool

  public var isAirPlay: Bool { section == .system && tool == Self.airPlayTool }

  public init(
    id: String, target: Target, section: Section, title: String, tool: String? = nil,
    image: String? = nil, primary: PortBinding, extras: [PortBinding] = [],
    directory: String? = nil, repositoryRoot: String? = nil, startedAt: Date? = nil,
    isLongRunning: Bool = false, likelyHTTP: Bool, canTerminate: Bool
  ) {
    self.id = id
    self.target = target
    self.section = section
    self.title = title
    self.tool = tool
    self.image = image
    self.primary = primary
    self.extras = extras
    self.directory = directory
    self.repositoryRoot = repositoryRoot
    self.startedAt = startedAt
    self.isLongRunning = isLongRunning
    self.likelyHTTP = likelyHTTP
    self.canTerminate = canTerminate
  }

}
