import DoorplateCore
import Foundation
import Testing

// Name stalled scan/continuation tests before the CI job's hard timeout.
@Suite(.timeLimit(.minutes(1))) struct ScannerTests {
  private let now = Date(timeIntervalSince1970: 1_793_772_000)

  @Test func secondScanWhileRunningReturnsNil() async throws {
    let docker = SuspendedDockerSource()
    let scanner = makeScanner(docker: docker)
    let first = Task { await scanner.scan(settings: SnapshotSettings()) }
    await docker.waitUntilStarted()
    let second = await scanner.scan(settings: SnapshotSettings())
    await docker.release()
    let completed = try #require(await first.value)
    #expect(second == nil)
    #expect(completed.failedAt == nil)
    #expect(completed.snapshot.dockerStatus == .ok)
    #expect(await scanner.scan(settings: SnapshotSettings()) != nil)
  }

  @Test func failureKeepsPreviousSnapshot() async throws {
    let source = FakeProcessSource(
      listeners: [Listener(pid: 101, port: 8080, address: "::1")],
      processes: [ProcessRecord(pid: 101, name: "node", startedAt: now, uid: 501)])
    let clock = ScanClock(now)
    let scanner = Scanner(
      processes: source, files: FakeFileProbe(), docker: FakeDockerSource(), currentUID: 501,
      now: { clock.read() })
    let first = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(first.snapshot.badgeCount == 1)
    source.failing = true
    let failedAt = now.addingTimeInterval(60)
    clock.set(failedAt)
    let failure = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(failure.snapshot == first.snapshot)
    #expect(failure.failedAt == failedAt)
    source.failing = false
    let recovered = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(recovered.failedAt == nil)
    #expect(recovered.snapshot.scannedAt == failedAt)
  }

  @Test func firstFailureGivesEmptySnapshot() async throws {
    let source = FakeProcessSource(failing: true)
    let scanner = makeScanner(processes: source)
    let result = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(result.snapshot == Snapshot.empty(at: now))
    #expect(result.failedAt == now)
  }

  @Test(arguments: [
    (DockerError.absent, DockerStatus.absent),
    (.notResponding, .notResponding),
    (.api(status: 500, message: "x"), .notResponding),
  ])
  func dockerErrorsMapToStatus(error: DockerError, status: DockerStatus) async throws {
    let scanner = makeScanner(docker: FakeDockerSource(result: .failure(error)))
    let result = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(result.snapshot.dockerStatus == status)
    #expect(result.snapshot.docker.isEmpty)
    #expect(result.failedAt == nil)
  }

  @Test func fetchesParentRecords() async throws {
    let source = FakeProcessSource(
      listeners: [Listener(pid: 102, port: 8080, address: "::1")],
      processes: [
        ProcessRecord(
          pid: 101, name: "java",
          arguments: ["java", "org.gradle.launcher.daemon.bootstrap.GradleDaemon"]),
        ProcessRecord(pid: 102, name: "java", parentPID: 101, startedAt: now, uid: 501),
      ])
    let scanner = makeScanner(processes: source)
    let result = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(result.snapshot.apps.map(\.tool) == ["gradle"])
  }

  /// The probe stays blocked for the whole test, so a scan that waited on it would never return.
  /// The bound only has to tell "returned after the 20 ms lookup budget" from "stuck"; it is
  /// generous because shared CI runners took ~225 ms for a scan that is ~20 ms locally.
  static let unblockedScanBound: Duration = .seconds(2)

  @Test(arguments: [false, true])
  func blockedProjectLookupKeepsScansUpdating(blockRead: Bool) async throws {
    let files = BlockingProjectProbe(blockRead: blockRead)
    defer { files.release.signal() }
    let source = FakeProcessSource(
      listeners: [Listener(pid: 101, port: 8080, address: "::1")],
      processes: [
        ProcessRecord(
          pid: 101, name: "node", executablePath: "/usr/bin/node",
          cwd: "/Users/dev/shop", startedAt: now, uid: 501)
      ])
    let date = now
    let scanner = Scanner(
      processes: source, files: files, docker: FakeDockerSource(), currentUID: 501,
      now: { date })
    let clock = ContinuousClock()
    let start = clock.now
    let first = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(start.duration(to: clock.now) < Self.unblockedScanBound)
    #expect(first.snapshot.apps.map(\.title) == ["node"])
    #expect(first.failedAt == nil)

    // The pending lookup must not keep isScanning set or freeze old port rows.
    source.listenerRecords = [Listener(pid: 101, port: 9090, address: "::1")]
    let nextStart = clock.now
    let next = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(nextStart.duration(to: clock.now) < Self.unblockedScanBound)
    #expect(next.snapshot.apps.map { $0.primary.port } == [9090])
    #expect(next.snapshot.apps.map(\.title) == ["node"])
    #expect(files.attempts == 1)

    files.release.signal()
    var titles: [String] = []
    for _ in 0..<100 {
      let result = try #require(await scanner.scan(settings: SnapshotSettings()))
      titles = result.snapshot.apps.map(\.title)
      if titles == ["shop-project"] { break }
      try await Task.sleep(for: .milliseconds(5))
    }
    #expect(titles == ["shop-project"])
  }

  @Test func manyPendingDirectoriesShareOneWaitBudget() async throws {
    let files = BlockingProjectProbe(blockRead: false)
    defer { files.release.signal() }
    let records = (101...130).map { pid in
      ProcessRecord(
        pid: Int32(pid), name: "node", executablePath: "/usr/bin/node",
        cwd: pid == 101 ? "/Users/dev/shop" : "/Users/dev/z-project-\(pid)")
    }
    let source = FakeProcessSource(
      listeners: records.map { Listener(pid: $0.pid, port: UInt16($0.pid), address: "::1") },
      processes: records)
    let scanner = Scanner(
      processes: source, files: files, docker: FakeDockerSource(), currentUID: 501,
      now: { Date() })
    let clock = ContinuousClock()
    let start = clock.now
    let result = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(start.duration(to: clock.now) < Self.unblockedScanBound)
    #expect(result.snapshot.apps.count == 30)
    #expect(result.snapshot.apps.allSatisfy { $0.title == "node" })
    source.listenerRecords = []
    let empty = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(empty.snapshot.apps.isEmpty)
  }

  private func makeScanner(
    processes: any ProcessSource = FakeProcessSource(),
    docker: any DockerSource = FakeDockerSource()
  ) -> DoorplateCore.Scanner {
    let date = now
    return Scanner(
      processes: processes, files: FakeFileProbe(), docker: docker, currentUID: 501,
      now: { date })
  }
}

private final class BlockingProjectProbe: FileProbe, @unchecked Sendable {
  let homeDirectory = "/Users/dev"
  let release = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private let blockRead: Bool
  private var count = 0
  var attempts: Int { lock.withLock { count } }

  init(blockRead: Bool) { self.blockRead = blockRead }

  func presence(_ path: String) -> FilePresence {
    guard path == "/Users/dev/shop/package.json" else { return .absent }
    lock.withLock { count += 1 }
    if !blockRead { waitForAnswer() }
    return .present
  }

  func read(_ path: String) -> String? {
    if blockRead { waitForAnswer() }
    return "{\"name\":\"shop-project\"}"
  }

  private func waitForAnswer() {
    // A finite safety timeout also makes the unfixed implementation fail, not hang.
    _ = release.wait(timeout: .now() + 1)
  }
}

private final class ScanClock: @unchecked Sendable {
  private let lock = NSLock()
  private var date: Date

  init(_ date: Date) { self.date = date }
  func read() -> Date { lock.withLock { date } }
  func set(_ date: Date) { lock.withLock { self.date = date } }
}

private actor SuspendedDockerSource: DockerSource {
  private var pending: CheckedContinuation<[Container], Never>?
  private var started: CheckedContinuation<Void, Never>?
  private var released = false

  func containers() async throws(DockerError) -> [Container] {
    if released { return [] }
    return await withCheckedContinuation { continuation in
      pending = continuation
      started?.resume()
      started = nil
    }
  }

  func waitUntilStarted() async {
    if pending != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func release() {
    released = true
    pending?.resume(returning: [])
    pending = nil
  }

  func stop(_ id: String) async throws(DockerError) {}
}
