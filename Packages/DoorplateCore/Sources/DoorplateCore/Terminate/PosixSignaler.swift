import Darwin
import Dispatch
import Foundation

public struct PosixSignaler: ProcessSignaler {
  public init() {}

  public func startTime(of pid: Int32) -> Date? {
    guard pid > 0 else { return nil }
    var info = proc_bsdinfo()
    let size = MemoryLayout<proc_bsdinfo>.size
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == Int32(size) else {
      return nil
    }
    return Date(
      timeIntervalSince1970: Double(info.pbi_start_tvsec) + Double(info.pbi_start_tvusec)
        / 1_000_000)
  }

  public func signal(_ sig: Int32, to pid: Int32) -> SignalResult {
    // POSIX treats zero and negative identifiers as process groups, never single targets.
    guard pid > 0 else { return .notPermitted }
    if Darwin.kill(pid, sig) == 0 { return .sent }
    return errno == ESRCH ? .noSuchProcess : .notPermitted
  }

  public func waitForExit(of pid: Int32, timeout: Duration) async -> Bool {
    guard pid > 0 else { return false }
    // Reading proc info avoids sending even signal zero to a vanished/reused identifier.
    var info = proc_bsdinfo()
    let size = MemoryLayout<proc_bsdinfo>.size
    if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == 0 && errno == ESRCH {
      return true
    }
    return await withCheckedContinuation { continuation in
      let wait = ProcessExitWait()
      wait.queue.async { wait.start(pid: pid, timeout: timeout, continuation: continuation) }
    }
  }
}

// All mutable state is confined to the private serial queue. Both sources retain the
// waiter until one completes; cancellation releases their handlers and breaks the cycle.
private final class ProcessExitWait: @unchecked Sendable {
  let queue = DispatchQueue(label: "io.github.junjuny0227.doorplate.terminate.wait")
  private var process: (any DispatchSourceProcess)?
  private var timer: (any DispatchSourceTimer)?
  private var continuation: CheckedContinuation<Bool, Never>?

  func start(pid: Int32, timeout: Duration, continuation: CheckedContinuation<Bool, Never>) {
    self.continuation = continuation
    let process = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: queue)
    let timer = DispatchSource.makeTimerSource(queue: queue)
    self.process = process
    self.timer = timer
    process.setEventHandler { self.finish(exited: true) }
    timer.setEventHandler { self.finish(exited: false) }
    let components = timeout.components
    let seconds = max(0, Double(components.seconds) + Double(components.attoseconds) / 1e18)
    timer.schedule(deadline: .now() + seconds)
    process.activate()
    timer.activate()
  }

  private func finish(exited: Bool) {
    guard let continuation else { return }
    self.continuation = nil
    process?.cancel()
    timer?.cancel()
    process = nil
    timer = nil
    continuation.resume(returning: exited)
  }
}
