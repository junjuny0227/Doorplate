import Darwin
import Foundation
import os

public enum StopOutcome: Sendable, Equatable {
  case stopped, alreadyGone, stillRunning, notPermitted
  case failed(String)
}

public struct Terminator: Sendable {
  private let signaler: any ProcessSignaler
  private let docker: any DockerSource
  private let gracePeriod: Duration
  private let logger = Logger(subsystem: "io.github.junjuny0227.doorplate", category: "terminate")

  public init(
    signaler: any ProcessSignaler, docker: any DockerSource, gracePeriod: Duration = .seconds(10)
  ) {
    self.signaler = signaler
    self.docker = docker
    self.gracePeriod = gracePeriod
  }

  public func stop(_ target: Target) async -> StopOutcome {
    switch target {
    case .process(let pid, let startedAt):
      return await stopProcess(pid, startedAt: startedAt, signal: SIGTERM, timeout: gracePeriod)
    case .container(let id):
      do {
        try await docker.stop(id)
        return .stopped
      } catch {
        logger.error("Docker stop failed: \(String(describing: error), privacy: .private)")
        return .failed(String(describing: error))
      }
    }
  }

  public func forceStop(_ target: Target) async -> StopOutcome {
    guard case .process(let pid, let startedAt) = target else {
      return .failed("Force stop is only supported for processes")
    }
    return await stopProcess(pid, startedAt: startedAt, signal: SIGKILL, timeout: .seconds(1))
  }

  private func stopProcess(
    _ pid: Int32, startedAt: Date?, signal: Int32, timeout: Duration
  ) async -> StopOutcome {
    guard let startedAt, pid > 0 else { return .notPermitted }
    guard let current = signaler.startTime(of: pid),
      abs(current.timeIntervalSince(startedAt)) <= 0.001
    else { return .alreadyGone }

    switch signaler.signal(signal, to: pid) {
    case .notPermitted:
      logger.error("Not permitted to stop process \(pid)")
      return .notPermitted
    case .noSuchProcess:
      return .alreadyGone
    case .sent:
      return await signaler.waitForExit(of: pid, timeout: timeout) ? .stopped : .stillRunning
    }
  }
}
