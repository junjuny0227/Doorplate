import Dispatch
import Foundation
import Testing

@testable import DoorplateCore

@Suite(.timeLimit(.minutes(1)))
struct TCCProjectLookupTests {
  @Test(arguments: ["Desktop", "Documents", "Downloads", "Library/Mobile Documents"])
  func pendingProtectedProjectUsesStartFolder(root: String) async {
    let directory = "/Users/dev/\(root)/waiting"
    let files = LaneProjectProbe(directory: directory)
    defer { files.release.signal() }
    let lookup = CachedProjectLookup(resolver: ProjectResolver(files: files))
    let snapshot = await lookup.prepare(directories: [directory])
    #expect(files.waitUntilBlocked() == .success)
    #expect(
      snapshot.resolve(startingAt: directory)
        == ProjectInfo(name: "waiting", directory: directory, repositoryRoot: nil))
  }

  @Test func expiredProjectRemainsVisibleDuringBlockedRefresh() async throws {
    let directory = "/Users/dev/shop"
    let files = LaneProjectProbe(directory: directory, blockOnAttempt: 2)
    defer { files.release.signal() }
    let lookup = CachedProjectLookup(resolver: ProjectResolver(files: files), ttl: 0)
    let first = await lookup.prepare(directories: [directory])
    #expect(first.resolve(startingAt: directory)?.name == "live-project")
    let refreshing = await lookup.prepare(directories: [directory])
    #expect(files.waitUntilBlocked() == .success)
    #expect(refreshing.resolve(startingAt: directory) == first.resolve(startingAt: directory))
    files.name = "refreshed-project"
    files.release.signal()
    let deadline = ContinuousClock.now + .seconds(2)
    var refreshed: ProjectInfo?
    repeat {
      refreshed = await lookup.prepare(directories: [directory]).resolve(startingAt: directory)
      if refreshed?.name == "refreshed-project" { break }
      try await Task.sleep(for: .milliseconds(5))
    } while ContinuousClock.now < deadline
    #expect(refreshed?.name == "refreshed-project")
    _ = await lookup.prepare(directories: [])
    #expect(first.resolve(startingAt: directory)?.name == "live-project")
  }

  @Test(arguments: ["scratch", "Downloads-other"])
  func unprotectedPendingProjectHasNoFolderFallback(root: String) async {
    let directory = "/Users/dev/\(root)/waiting"
    let files = LaneProjectProbe(directory: directory)
    defer { files.release.signal() }
    let lookup = CachedProjectLookup(resolver: ProjectResolver(files: files))
    let snapshot = await lookup.prepare(directories: [directory])
    #expect(files.waitUntilBlocked() == .success)
    #expect(snapshot.resolve(startingAt: directory) == nil)
  }

  @Test func blockedDownloadsDoesNotDelayUnprotectedProject() async throws {
    let protected = "/Users/dev/Downloads/waiting"
    let other = "/Users/dev/scratch/live-check-app"
    let files = LaneProjectProbe(directory: protected)
    defer { files.release.signal() }
    let lookup = CachedProjectLookup(resolver: ProjectResolver(files: files))
    _ = await lookup.prepare(directories: [protected])
    #expect(files.waitUntilBlocked() == .success)
    // Seconds distinguish an independent lane from a stuck lookup, not performance.
    let deadline = ContinuousClock.now + .seconds(2)
    var project: ProjectInfo?
    repeat {
      project = await lookup.prepare(directories: [protected, other]).resolve(startingAt: other)
      if project != nil { break }
      try await Task.sleep(for: .milliseconds(5))
    } while ContinuousClock.now < deadline
    #expect(project?.name == "live-project")
  }
}

private final class LaneProjectProbe: FileProbe, @unchecked Sendable {
  let homeDirectory = "/Users/dev"
  let entered = DispatchSemaphore(value: 0)
  let release = DispatchSemaphore(value: 0)
  private let directory: String
  private let blockOnAttempt: Int
  private let lock = NSLock()
  private var attempts = 0
  private var storedName = "live-project"
  var name: String {
    get { lock.withLock { storedName } }
    set { lock.withLock { storedName = newValue } }
  }

  func waitUntilBlocked() -> DispatchTimeoutResult { entered.wait(timeout: .now() + 2) }

  init(directory: String, blockOnAttempt: Int = 1) {
    self.directory = directory
    self.blockOnAttempt = blockOnAttempt
  }

  func presence(_ path: String) -> FilePresence {
    let shouldBlock =
      path == directory + "/package.json"
      && lock.withLock {
        attempts += 1
        return attempts == blockOnAttempt
      }
    if shouldBlock {
      entered.signal()
      release.wait()
    }
    return path.hasSuffix("/package.json") ? .present : .absent
  }

  func read(_ path: String) -> String? { "{\"name\":\"\(name)\"}" }
}
