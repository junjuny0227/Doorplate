import Dispatch
import Foundation

/// Classifier can use a synchronous fixture resolver or an immutable cache snapshot.
public protocol ProjectLookup: Sendable {
  func resolve(startingAt directory: String) -> ProjectInfo?
}

extension ProjectResolver: ProjectLookup {}

struct ResolvedProjects: ProjectLookup {
  let projects: [String: ProjectInfo]

  func resolve(startingAt directory: String) -> ProjectInfo? { projects[directory] }
}

/// Only the worker queue touches FileProbe. No filesystem work happens under the lock.
/// All mutable state is lock-protected; a blocked syscall occupies at most one worker.
final class CachedProjectLookup: @unchecked Sendable {
  private struct Entry {
    let project: ProjectInfo?
    let resolvedAt: Date
  }

  private let resolver: ProjectResolver
  private let queue = DispatchQueue(
    label: "io.github.junjuny0227.doorplate.projects", qos: .utility)
  private let lock = NSLock()
  private let ttl: TimeInterval
  private let now: @Sendable () -> Date
  private var entries: [String: Entry] = [:]
  private var pending: [String: DispatchGroup] = [:]
  private var active: Set<String> = []

  init(
    resolver: ProjectResolver, ttl: TimeInterval = 30,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.resolver = resolver
    self.ttl = ttl
    self.now = now
  }

  func prepare(directories: Set<String>) async -> ResolvedProjects {
    // One deadline for the whole batch, not one timeout per process/directory.
    let deadline = DispatchTime.now() + .milliseconds(20)
    let date = now()
    let groups: [DispatchGroup] = lock.withLock {
      active = directories
      entries = entries.filter {
        directories.contains($0.key) && date.timeIntervalSince($0.value.resolvedAt) < ttl
      }
      return directories.sorted().compactMap { directory in
        guard entries[directory] == nil else { return nil }
        if let group = pending[directory] { return group }
        let group = DispatchGroup()
        group.enter()
        pending[directory] = group
        queue.async { [self] in
          // A previously queued directory may have disappeared while another lookup blocked.
          let needed = lock.withLock { active.contains(directory) }
          let project = needed ? resolver.resolve(startingAt: directory) : nil
          let resolvedAt = now()
          lock.withLock {
            if active.contains(directory), needed {
              entries[directory] = Entry(project: project, resolvedAt: resolvedAt)
            }
            pending.removeValue(forKey: directory)
          }
          group.leave()
        }
        return group
      }
    }
    if !groups.isEmpty {
      // Do not block a cooperative executor (or the Scanner actor) while waiting.
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.global(qos: .utility).async {
          for group in groups {
            if group.wait(timeout: deadline) == .timedOut { break }
          }
          continuation.resume()
        }
      }
    }
    return lock.withLock {
      ResolvedProjects(projects: entries.compactMapValues(\.project))
    }
  }
}
