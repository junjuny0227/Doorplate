import Foundation

public enum Exposure: String, Sendable, Equatable, Codable { case loopback, network }

public struct Listener: Sendable, Equatable, Codable {
  public var pid: Int32
  public var port: UInt16
  public var address: String
  public var socketID: UInt64?
  public init(pid: Int32, port: UInt16, address: String, socketID: UInt64? = nil) {
    self.pid = pid
    self.port = port
    self.address = address
    self.socketID = socketID
  }
  public var exposure: Exposure {
    switch address {
    case "127.0.0.1", "::1", "::ffff:127.0.0.1": .loopback
    default: .network
    }
  }
}

public struct ProcessRecord: Sendable, Equatable, Codable {
  public var pid: Int32
  public var name: String
  public var executablePath: String?
  public var arguments: [String]?
  public var cwd: String?
  public var parentPID: Int32?
  public var startedAt: Date?
  public var uid: UInt32?
  public init(
    pid: Int32, name: String, executablePath: String? = nil, arguments: [String]? = nil,
    cwd: String? = nil, parentPID: Int32? = nil, startedAt: Date? = nil, uid: UInt32? = nil
  ) {
    self.pid = pid
    self.name = name
    self.executablePath = executablePath
    self.arguments = arguments
    self.cwd = cwd
    self.parentPID = parentPID
    self.startedAt = startedAt
    self.uid = uid
  }

}

public struct Container: Sendable, Equatable, Codable {
  public var id: String
  public var name: String
  public var image: String
  public var composeProject: String?
  public var composeService: String?
  public var composeWorkingDir: String?
  public var publishedPorts: [PortBinding]
  public var startedAt: Date?
  public init(
    id: String, name: String, image: String, composeProject: String? = nil,
    composeService: String? = nil, composeWorkingDir: String? = nil, publishedPorts: [PortBinding],
    startedAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.image = image
    self.composeProject = composeProject
    self.composeService = composeService
    self.composeWorkingDir = composeWorkingDir
    self.publishedPorts = publishedPorts
    self.startedAt = startedAt
  }

}
