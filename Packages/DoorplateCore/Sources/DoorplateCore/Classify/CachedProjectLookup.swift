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

/// Only the five worker lanes probe project files. No filesystem work happens under the lock.
/// All mutable state is lock-protected; each protected root can block at most one lane.
final class CachedProjectLookup: @unchecked Sendable {
  private struct Entry {
    let project: ProjectInfo?
    let resolvedAt: Date
  }

  private let resolver: ProjectResolver
  private let protectedRoots: [String]
  private let queues: [DispatchQueue]
  private let lock = NSLock()
  private let ttl: TimeInterval
  private let now: @Sendable () -> Date
  private var entries: [String: Entry] = [:]
  private var pending: [String: DispatchGroup] = [:]
  private var active: Set<String> = []

  init(
    resolver: ProjectResolver, ttl: TimeInterval = 30, homeDirectory: String? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.resolver = resolver
    let home = URL(fileURLWithPath: homeDirectory ?? resolver.homeDirectory)
    self.protectedRoots = ["Desktop", "Documents", "Downloads", "Library/Mobile Documents"].map {
      home.appendingPathComponent($0).standardizedFileURL.path
    }
    self.queues = (0..<5).map {
      DispatchQueue(label: "io.github.junjuny0227.doorplate.projects.\($0)", qos: .utility)
    }
    self.ttl = ttl
    self.now = now
  }

  private func lane(for directory: String) -> Int {
    let path = URL(fileURLWithPath: directory).standardizedFileURL.path
    return protectedRoots.firstIndex { path == $0 || path.hasPrefix($0 + "/") } ?? 4
  }

  func prepare(directories: Set<String>) async -> ResolvedProjects {
    // One deadline for the whole batch, not one timeout per process/directory.
    let deadline = DispatchTime.now() + .milliseconds(20)
    let date = now()
    let groups: [DispatchGroup] = lock.withLock {
      active = directories
      entries = entries.filter { directories.contains($0.key) }
      return directories.sorted().compactMap { directory in
        if let entry = entries[directory], date.timeIntervalSince(entry.resolvedAt) < ttl {
          return nil
        }
        if let group = pending[directory] { return group }
        let group = DispatchGroup()
        group.enter()
        pending[directory] = group
        queues[lane(for: directory)].async { [self] in
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
      var projects = entries.compactMapValues(\.project)
      for directory in directories
      where entries[directory] == nil && pending[directory] != nil && lane(for: directory) < 4 {
        projects[directory] = resolver.inaccessibleProject(startingAt: directory)
      }
      return ResolvedProjects(projects: projects)
    }
  }
}
