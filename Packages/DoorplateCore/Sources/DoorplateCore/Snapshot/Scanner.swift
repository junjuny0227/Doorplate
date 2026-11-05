import Foundation
import os

public struct ScanOutcome: Sendable, Equatable {
  public var snapshot: Snapshot
  public var failedAt: Date?

  public init(snapshot: Snapshot, failedAt: Date?) {
    self.snapshot = snapshot
    self.failedAt = failedAt
  }
}

public actor Scanner {
  private let processes: any ProcessSource
  private let docker: any DockerSource
  private let projects: CachedProjectLookup
  private let fixtureLookup: (any ProjectLookup)?
  private let currentUID: UInt32
  private let now: @Sendable () -> Date
  private let logger = Logger(subsystem: "io.github.junjuny0227.doorplate", category: "scan")
  private var isScanning = false
  private var previousSnapshot: Snapshot?

  public init(
    processes: any ProcessSource, files: any FileProbe, docker: any DockerSource,
    currentUID: UInt32, now: @escaping @Sendable () -> Date,
    fixtureLookup: (any ProjectLookup)? = nil
  ) {
    self.processes = processes
    self.docker = docker
    self.fixtureLookup = fixtureLookup
    projects = CachedProjectLookup(resolver: ProjectResolver(files: files))
    self.currentUID = currentUID
    self.now = now
  }

  public func scan(settings: SnapshotSettings) async -> ScanOutcome? {
    guard !isScanning else { return nil }
    isScanning = true
    defer { isScanning = false }

    let listeners: [Listener]
    do {
      listeners = try processes.listeners()
    } catch {
      logger.error("Failed to collect listeners")
      let failedAt = now()
      return ScanOutcome(
        snapshot: previousSnapshot ?? Snapshot.empty(at: failedAt), failedAt: failedAt)
    }

    var records: [Int32: ProcessRecord] = [:]
    for pid in Set(listeners.map(\.pid)).sorted() {
      if let record = processes.process(pid) { records[pid] = record }
    }
    let parents = Set(records.values.compactMap(\.parentPID))
    for pid in parents.sorted() where records[pid] == nil {
      if let record = processes.process(pid) { records[pid] = record }
    }

    let containers: [Container]
    let dockerStatus: DockerStatus
    do {
      containers = try await docker.containers()
      dockerStatus = .ok
    } catch {
      containers = []
      dockerStatus = error == .absent ? .absent : .notResponding
    }
    let publishedPorts = Set(containers.flatMap { $0.publishedPorts.map(\.port) })
    let projectDirectories = Set(
      listeners.filter { !publishedPorts.contains($0.port) }.compactMap {
        records[$0.pid].flatMap { ProjectResolver.startDirectory(for: $0) }
      })
    let resolved: any ProjectLookup
    if let fixtureLookup {
      // Fixture replay is synchronous and has no filesystem access or timing-dependent fallback.
      resolved = fixtureLookup
    } else {
      resolved = await projects.prepare(directories: projectDirectories)
    }
    let classifier = Classifier(resolver: resolved, currentUID: currentUID)
    let entries = classifier.classify(
      listeners: listeners, processes: records, containers: containers)
    let snapshot = SnapshotBuilder.build(
      entries, dockerStatus: dockerStatus, settings: settings, now: now())
    previousSnapshot = snapshot
    return ScanOutcome(snapshot: snapshot, failedAt: nil)
  }
}
