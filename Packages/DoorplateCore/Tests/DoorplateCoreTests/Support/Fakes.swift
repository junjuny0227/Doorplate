import DoorplateCore
import Foundation

// Every mutable fake stores its state behind this lock, including test-side writes.
private final class FakeState<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) { self.value = value }

  func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
    try lock.withLock { try body(&value) }
  }
}

final class FakeProcessSource: ProcessSource, Sendable {
  enum Failure: Error { case listeners }

  private struct State {
    var listeners: [Listener]
    var processes: [Int32: ProcessRecord]
    var failing: Bool
  }

  private let state: FakeState<State>

  init(listeners: [Listener] = [], processes: [ProcessRecord] = [], failing: Bool = false) {
    state = FakeState(
      State(
        listeners: listeners,
        processes: Dictionary(
          processes.map { ($0.pid, $0) }, uniquingKeysWith: { _, last in last }),
        failing: failing))
  }

  init(listeners: [Listener] = [], processes: [Int32: ProcessRecord], failing: Bool = false) {
    state = FakeState(State(listeners: listeners, processes: processes, failing: failing))
  }

  var failing: Bool {
    get { state.withLock { $0.failing } }
    set { state.withLock { $0.failing = newValue } }
  }

  var records: [Int32: ProcessRecord] {
    get { state.withLock { $0.processes } }
    set { state.withLock { $0.processes = newValue } }
  }

  var listenerRecords: [Listener] {
    get { state.withLock { $0.listeners } }
    set { state.withLock { $0.listeners = newValue } }
  }

  func listeners() throws -> [Listener] {
    try state.withLock {
      if $0.failing { throw Failure.listeners }
      return $0.listeners
    }
  }

  func process(_ pid: Int32) -> ProcessRecord? { state.withLock { $0.processes[pid] } }
}

struct FakeFileProbe: FileProbe {
  var homeDirectory: String
  var files: [String: String]
  var denied: [String]

  init(home: String = "/Users/dev", files: [String: String] = [:], denied: [String] = []) {
    homeDirectory = home
    self.files = files
    self.denied = denied
  }

  func presence(_ path: String) -> FilePresence {
    if denied.contains(where: { root in
      let boundary =
        root == "/" ? root : root.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let absoluteRoot = root.hasPrefix("/") && boundary != "/" ? "/" + boundary : boundary
      return path == absoluteRoot || path.hasPrefix(absoluteRoot == "/" ? "/" : absoluteRoot + "/")
    }) {
      return .denied
    }
    return files[path] == nil ? .absent : .present
  }

  func read(_ path: String) -> String? { presence(path) == .present ? files[path] : nil }
}

final class FakeDockerSource: DockerSource, Sendable {
  private struct State {
    var result: Result<[Container], DockerError>
    var stopResult: Result<Void, DockerError>
    var stopped: [String] = []
  }

  private let state: FakeState<State>

  init(
    result: Result<[Container], DockerError> = .success([]),
    stopResult: Result<Void, DockerError> = .success(())
  ) {
    state = FakeState(State(result: result, stopResult: stopResult))
  }

  var result: Result<[Container], DockerError> {
    get { state.withLock { $0.result } }
    set { state.withLock { $0.result = newValue } }
  }

  var stopResult: Result<Void, DockerError> {
    get { state.withLock { $0.stopResult } }
    set { state.withLock { $0.stopResult = newValue } }
  }

  var stopped: [String] { state.withLock { $0.stopped } }

  func containers() async throws(DockerError) -> [Container] { try result.get() }

  func stop(_ id: String) async throws(DockerError) {
    let result = state.withLock {
      $0.stopped.append(id)
      return $0.stopResult
    }
    try result.get()
  }
}

final class FakeQuitter: AppQuitter, Sendable {
  private let apps: Set<Int32>
  private let requests = FakeState<[Int32]>([])
  init(apps: Set<Int32>) { self.apps = apps }
  var requested: [Int32] { requests.withLock { $0 } }
  func requestQuit(pid: Int32) async -> Bool {
    requests.withLock { $0.append(pid) }
    return apps.contains(pid)
  }
}

final class FakeSignaler: ProcessSignaler, Sendable {
  struct SentSignal: Sendable, Equatable {
    var signal: Int32
    var pid: Int32
  }

  struct Wait: Sendable, Equatable {
    var pid: Int32
    var timeout: Duration
  }

  private struct State {
    var startTimes: [Int32: Date]
    var exits: Bool
    var forcedResult: SignalResult?
    var sentSignals: [SentSignal] = []
    var waits: [Wait] = []
  }

  private let state: FakeState<State>

  init(startTimes: [Int32: Date] = [:], exits: Bool = true, forcedResult: SignalResult? = nil) {
    state = FakeState(State(startTimes: startTimes, exits: exits, forcedResult: forcedResult))
  }

  var startTimes: [Int32: Date] {
    get { state.withLock { $0.startTimes } }
    set { state.withLock { $0.startTimes = newValue } }
  }

  var exits: Bool {
    get { state.withLock { $0.exits } }
    set { state.withLock { $0.exits = newValue } }
  }

  var forcedResult: SignalResult? {
    get { state.withLock { $0.forcedResult } }
    set { state.withLock { $0.forcedResult = newValue } }
  }

  var sentSignals: [SentSignal] { state.withLock { $0.sentSignals } }
  var signals: [Int32] { sentSignals.map(\.signal) }
  var waits: [Wait] { state.withLock { $0.waits } }

  func startTime(of pid: Int32) -> Date? { state.withLock { $0.startTimes[pid] } }

  func signal(_ sig: Int32, to pid: Int32) -> SignalResult {
    state.withLock {
      $0.sentSignals.append(SentSignal(signal: sig, pid: pid))
      return $0.forcedResult ?? .sent
    }
  }

  func waitForExit(of pid: Int32, timeout: Duration) async -> Bool {
    state.withLock {
      $0.waits.append(Wait(pid: pid, timeout: timeout))
      return $0.exits
    }
  }
}
