import Foundation

public struct Classifier: Sendable {
  private let resolver: ProjectResolver
  private let currentUID: UInt32

  public init(resolver: ProjectResolver, currentUID: UInt32) {
    self.resolver = resolver
    self.currentUID = currentUID
  }

  public func classify(
    listeners: [Listener], processes: [Int32: ProcessRecord], containers: [Container]
  ) -> [ServerEntry] {
    let sockets = Dictionary(
      grouping: listeners.filter { $0.socketID != nil }, by: { $0.socketID! })
    let owners = sockets.mapValues { sharers in
      let pids = Set(sharers.map(\.pid))
      let topmost = pids.filter { pid in
        guard let parent = processes[pid]?.parentPID else { return true }
        return !pids.contains(parent)
      }
      // A corrupt parent cycle has no ancestor; retain a deterministic owner.
      return topmost.min() ?? pids.min()!
    }
    let owned = listeners.filter { listener in
      guard let socket = listener.socketID else { return true }
      return owners[socket] == listener.pid
    }
    let grouped = Dictionary(grouping: owned, by: \.pid)
    return grouped.keys.sorted().compactMap { pid in
      guard let process = processes[pid], let listeners = grouped[pid] else { return nil }
      return processEntry(process, listeners: listeners, processes: processes)
    }
  }

  private func processEntry(
    _ process: ProcessRecord, listeners: [Listener], processes: [Int32: ProcessRecord]
  ) -> ServerEntry {
    let match = ToolDetector.detect(
      process, parent: process.parentPID.flatMap { processes[$0] }, ports: listeners.map(\.port))
    let project = ProjectResolver.startDirectory(for: process).flatMap {
      resolver.resolve(startingAt: $0)
    }
    let arguments = process.arguments ?? []
    let jar = arguments.firstIndex(of: "-jar").flatMap { index in
      arguments.indices.contains(index + 1)
        ? (arguments[index + 1] as NSString).lastPathComponent : nil
    }
    let executable = process.executablePath.map { ($0 as NSString).lastPathComponent }
    let ports = PortRoleDetector.assign(listeners, arguments: arguments)
    return ServerEntry(
      id: "pid:\(process.pid)", target: .process(pid: process.pid, startedAt: process.startedAt),
      section: match.section,
      title: match.title ?? project?.name ?? jar ?? executable ?? process.name,
      tool: match.tool, primary: ports.primary, extras: ports.extras,
      directory: project?.directory, repositoryRoot: project?.repositoryRoot,
      startedAt: process.startedAt,
      isLongRunning: false, likelyHTTP: HTTPGuess.likelyHTTP(port: ports.primary.port, image: nil),
      canTerminate: process.uid == currentUID && process.startedAt != nil
        && match.section != .system && match.section != .hidden(.otherApp))
  }
}
