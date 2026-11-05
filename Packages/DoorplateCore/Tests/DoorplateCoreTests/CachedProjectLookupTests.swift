import Foundation
import Testing

@testable import DoorplateCore

@Suite struct CachedProjectLookupTests {
  private let directory = "/Users/dev/shop"

  @Test func fastLookupsResolveOnFirstScanAndShareDirectory() async throws {
    let files = MutableProjectProbe()
    let source = FakeProcessSource(
      listeners: [
        Listener(pid: 101, port: 8080, address: "::1"),
        Listener(pid: 102, port: 9090, address: "::1"),
      ],
      processes: [
        ProcessRecord(pid: 101, name: "node", cwd: directory),
        ProcessRecord(pid: 102, name: "node", cwd: directory),
      ])
    let scanner = Scanner(
      processes: source, files: files, docker: FakeDockerSource(), currentUID: 501,
      now: { Date() })
    let result = try #require(await scanner.scan(settings: SnapshotSettings()))
    #expect(result.snapshot.apps.map(\.title) == ["first-name", "first-name"])
    #expect(files.attempts == 1)
  }

  @Test func disappearingDirectoryIsResolvedAgainOnRestart() async {
    let files = MutableProjectProbe()
    let lookup = CachedProjectLookup(resolver: ProjectResolver(files: files))
    let first = await lookup.prepare(directories: [directory])
    #expect(first.resolve(startingAt: directory)?.name == "first-name")
    _ = await lookup.prepare(directories: [])
    files.name = "renamed"
    let restarted = await lookup.prepare(directories: [directory])
    #expect(restarted.resolve(startingAt: directory)?.name == "renamed")
    #expect(files.attempts == 2)
    // Classification sees immutable values, not later cache writes.
    #expect(first.resolve(startingAt: directory)?.name == "first-name")
  }

  @Test func ttlRefreshesActiveDirectoriesIncludingNegativeResults() async {
    let files = MutableProjectProbe()
    files.name = nil
    let lookup = CachedProjectLookup(
      resolver: ProjectResolver(files: files), ttl: 30, now: { files.date })
    let missing = await lookup.prepare(directories: [directory])
    #expect(missing.resolve(startingAt: directory) == nil)
    files.name = "created-later"
    let cached = await lookup.prepare(directories: [directory])
    #expect(cached.resolve(startingAt: directory) == nil)
    #expect(files.attempts == 1)
    files.date = files.date.addingTimeInterval(31)
    let refreshed = await lookup.prepare(directories: [directory])
    #expect(refreshed.resolve(startingAt: directory)?.name == "created-later")
    #expect(files.attempts == 2)
    files.name = "renamed-again"
    files.date = files.date.addingTimeInterval(31)
    let renamed = await lookup.prepare(directories: [directory])
    #expect(renamed.resolve(startingAt: directory)?.name == "renamed-again")
  }
}

private final class MutableProjectProbe: FileProbe, @unchecked Sendable {
  let homeDirectory = "/Users/dev"
  private let lock = NSLock()
  private var storedName: String? = "first-name"
  private var storedDate = Date(timeIntervalSince1970: 1_793_772_000)
  private var count = 0
  var attempts: Int { lock.withLock { count } }
  var name: String? {
    get { lock.withLock { storedName } }
    set { lock.withLock { storedName = newValue } }
  }
  var date: Date {
    get { lock.withLock { storedDate } }
    set { lock.withLock { storedDate = newValue } }
  }

  func presence(_ path: String) -> FilePresence {
    guard path == "/Users/dev/shop/package.json" else { return .absent }
    return lock.withLock {
      count += 1
      return storedName == nil ? .absent : .present
    }
  }

  func read(_ path: String) -> String? { name.map { "{\"name\":\"\($0)\"}" } }
}
