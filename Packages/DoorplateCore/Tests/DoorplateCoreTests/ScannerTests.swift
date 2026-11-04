import DoorplateCore
import Foundation
import Testing

@Suite struct ScannerTests {
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
