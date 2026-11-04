import DoorplateCore
import DoorplateMenu
import Foundation

/// Records fake process operations only; never touches a real PID.
final class FakeSignaler: ProcessSignaler, @unchecked Sendable {
  struct Signal: Equatable {
    var value: Int32
    var pid: Int32
  }

  struct Wait: Equatable {
    var pid: Int32
    var timeout: Duration
  }

  private let lock = NSLock()
  private var recordedSignals: [Signal] = []
  private var recordedWaits: [Wait] = []
  private var exits: [Bool]
  let startedAt: Date?
  let result: SignalResult

  init(startedAt: Date? = Date(timeIntervalSince1970: 1_000),
       result: SignalResult = .sent, exits: [Bool] = [true]) {
    self.startedAt = startedAt
    self.result = result
    self.exits = exits
  }

  var signals: [Signal] { lock.withLock { recordedSignals } }
  var waits: [Wait] { lock.withLock { recordedWaits } }

  func startTime(of pid: Int32) -> Date? { startedAt }

  func signal(_ sig: Int32, to pid: Int32) -> SignalResult {
    lock.withLock { recordedSignals.append(Signal(value: sig, pid: pid)) }
    return result
  }

  func waitForExit(of pid: Int32, timeout: Duration) async -> Bool {
    lock.withLock {
      recordedWaits.append(Wait(pid: pid, timeout: timeout))
      return exits.isEmpty ? false : exits.removeFirst()
    }
  }
}

actor FakeDocker: DockerSource {
  private(set) var stopped: [String] = []
  let error: DockerError?

  init(error: DockerError? = nil) { self.error = error }

  func containers() async throws(DockerError) -> [Container] { [] }

  func stop(_ id: String) async throws(DockerError) {
    stopped.append(id)
    if let error { throw error }
  }
}

@MainActor final class FakePrompter: StopPrompter {
  var answers: [Bool] = []
  var suspendPrompt = false
  private(set) var titles: [String] = []
  private(set) var messages: [String] = []
  private(set) var beepCount = 0
  var onBeep: (() -> Void)?
  private var pendingAnswer: CheckedContinuation<Bool, Never>?
  private var promptObserver: CheckedContinuation<Void, Never>?

  func askToForceStop(title: String) async -> Bool {
    titles.append(title)
    if suspendPrompt {
      return await withCheckedContinuation { continuation in
        pendingAnswer = continuation
        promptObserver?.resume()
        promptObserver = nil
      }
    }
    return answers.isEmpty ? true : answers.removeFirst()
  }

  func waitUntilAsked() async {
    if pendingAnswer != nil { return }
    await withCheckedContinuation { promptObserver = $0 }
  }

  func answer(_ force: Bool) {
    let continuation = pendingAnswer
    pendingAnswer = nil
    continuation?.resume(returning: force)
  }

  func report(_ message: String) { messages.append(message) }
  func signalAlreadyGone() {
    beepCount += 1
    onBeep?()
  }
}
