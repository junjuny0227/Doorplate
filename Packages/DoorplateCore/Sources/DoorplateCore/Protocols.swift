import Foundation

public protocol ProcessSource: Sendable {
  func listeners() throws -> [Listener]
  func process(_ pid: Int32) -> ProcessRecord?
}

public enum FilePresence: String, Sendable, Equatable, Codable { case absent, present, denied }

public protocol FileProbe: Sendable {
  var homeDirectory: String { get }
  func presence(_ path: String) -> FilePresence
  func read(_ path: String) -> String?
}

public enum DockerError: Error, Sendable, Equatable {
  case absent, notResponding
  case api(status: Int, message: String)
}

public protocol DockerSource: Sendable {
  func containers() async throws(DockerError) -> [Container]
  func stop(_ id: String) async throws(DockerError)
}

public enum SignalResult: Sendable, Equatable { case sent, noSuchProcess, notPermitted }

public protocol ProcessSignaler: Sendable {
  func startTime(of pid: Int32) -> Date?
  func signal(_ sig: Int32, to pid: Int32) -> SignalResult
  func waitForExit(of pid: Int32, timeout: Duration) async -> Bool
}
