import Darwin
import DoorplateCore
import Foundation

// Observe the Scanner's single collection pass without enumerating listeners twice.
private final class DiagnosticProcessSource: ProcessSource, @unchecked Sendable {
  private let source = LibprocProcessSource()
  private let lock = NSLock()
  private var count = 0

  var listenerCount: Int { lock.withLock { count } }

  func listeners() throws -> [Listener] {
    let listeners = try source.listeners()
    lock.withLock { count = listeners.count }
    return listeners
  }

  func process(_ pid: Int32) -> ProcessRecord? { source.process(pid) }
}

private func processCount() throws -> Int {
  for _ in 0..<4 {
    let estimated = proc_listallpids(nil, 0)
    guard estimated > 0 else { throw POSIXError(.EIO) }
    var pids = [Int32](repeating: 0, count: Int(estimated) + 256)
    let capacity = Int32(pids.count * MemoryLayout<Int32>.stride)
    let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, capacity) }
    guard count > 0 else { throw POSIXError(.EIO) }
    if count < pids.count { return pids.prefix(Int(count)).filter { $0 > 0 }.count }
  }
  throw POSIXError(.EAGAIN)
}

private func fixture(
  processes: any ProcessSource, files: any FileProbe, docker: any DockerSource,
  settings: SnapshotSettings, currentUID: UInt32
) async throws -> ScanFixture {
  let listeners = try processes.listeners()
  var records: [Int32: ProcessRecord] = [:]
  for pid in Set(listeners.map(\.pid)).sorted() {
    if let record = processes.process(pid) { records[pid] = record }
  }
  let parents = Set(records.values.compactMap(\.parentPID))
  for pid in parents.sorted() where records[pid] == nil {
    if let record = processes.process(pid) { records[pid] = record }
  }
  let containers: [Container]
  let status: DockerStatus
  do {
    containers = try await docker.containers()
    status = .ok
  } catch {
    containers = []
    status = error == .absent ? .absent : .notResponding
  }
  let recording = RecordingFileProbe(wrapping: files)
  let classifier = Classifier(resolver: ProjectResolver(files: recording), currentUID: currentUID)
  _ = classifier.classify(listeners: listeners, processes: records, containers: containers)
  return ScanFixture(
    now: Date(), home: files.homeDirectory, currentUID: currentUID, settings: settings,
    listeners: listeners, processes: records.values.sorted { $0.pid < $1.pid },
    files: recording.recorded, denied: recording.denied,
    docker: .init(status: status, containers: containers))
}

private enum ScanError: Error { case failed }

do {
  let arguments = Array(CommandLine.arguments.dropFirst())
  guard arguments.isEmpty || arguments == ["--fixture"] else {
    try FileHandle.standardError.write(contentsOf: Data("usage: doorplate-scan [--fixture]\n".utf8))
    exit(2)
  }
  let clock = ContinuousClock()
  let start = clock.now
  let count = try processCount()
  let processes = DiagnosticProcessSource()
  let files = LocalFileProbe()
  let docker = UnixSocketDockerSource(
    candidatePaths: UnixSocketDockerSource.defaultPaths(home: files.homeDirectory))
  let settings = SnapshotSettings()
  let uid = getuid()
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  encoder.dateEncodingStrategy = .iso8601

  // Finish timing before JSON serialization and stdout I/O, in both modes.
  let output: Data
  let elapsed: Duration
  if arguments == ["--fixture"] {
    let value = try await fixture(
      processes: processes, files: files, docker: docker, settings: settings, currentUID: uid)
    elapsed = start.duration(to: clock.now)
    output = try encoder.encode(value)
  } else {
    let scanner = DoorplateCore.Scanner(
      processes: processes, files: files, docker: docker, currentUID: uid, now: { Date() })
    guard let result = await scanner.scan(settings: settings), result.failedAt == nil else {
      throw ScanError.failed
    }
    elapsed = start.duration(to: clock.now)
    output = try encoder.encode(result.snapshot)
  }
  let parts = elapsed.components
  let milliseconds = Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
  let summary =
    "\(count) processes, \(processes.listenerCount) listeners, \(String(format: "%.3f", milliseconds)) ms\n"
  try FileHandle.standardError.write(contentsOf: Data(summary.utf8))
  try FileHandle.standardOutput.write(contentsOf: output + Data([0x0A]))
} catch {
  // Avoid leaking paths from system errors into diagnostics; fixture/stdout is opt-in data.
  try? FileHandle.standardError.write(
    contentsOf: Data("doorplate-scan: scan or output failed\n".utf8))
  exit(1)
}
