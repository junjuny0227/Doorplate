import DoorplateCore

@MainActor public protocol StopPrompter: AnyObject {
  /// Returns true to force stop, or false to send SIGTERM again and wait another grace period.
  func askToForceStop(title: String) async -> Bool
  /// Asks once before a group's Stop All (spec 9.8). `servers` lists the rows to stop.
  func confirmStopAll(name: String, servers: [String]) async -> Bool
  func report(_ message: String)
  func signalAlreadyGone()
}

@MainActor public final class StopCoordinator {
  private let terminator: Terminator
  private let prompter: any StopPrompter
  private let onChange: () -> Void
  public private(set) var stopping: Set<String> = []

  public init(
    terminator: Terminator, prompter: any StopPrompter, onChange: @escaping () -> Void
  ) {
    self.terminator = terminator
    self.prompter = prompter
    self.onChange = onChange
  }

  /// Stops a group's rows after one confirmation. Rows already stopping are skipped, and the
  /// rest start together so their grace periods overlap instead of adding up.
  public func stopAll(_ refs: [EntryRef], name: String) async {
    let pending = refs.filter { !stopping.contains($0.id) }
    guard !pending.isEmpty,
      await prompter.confirmStopAll(name: name, servers: pending.map { "\($0.port)  \($0.title)" })
    else { return }
    await withTaskGroup(of: Void.self) { group in
      for ref in pending { group.addTask { await self.stop(ref) } }
    }
  }

  public func stop(_ ref: EntryRef) async {
    guard stopping.insert(ref.id).inserted else { return }
    onChange()
    defer {
      stopping.remove(ref.id)
      // The caller updates MenuState and immediately rescans, including when already gone.
      onChange()
    }

    var outcome = await terminator.stop(ref.target)
    var forced = false
    while true {
      switch outcome {
      case .stopped:
        return
      case .alreadyGone:
        prompter.signalAlreadyGone()
        return
      case .notPermitted:
        prompter.report(L10n.text(.alertNotPermitted))
        return
      case .failed(let message):
        prompter.report(L10n.format(.alertDockerFailed, message))
        return
      case .stillRunning:
        guard !forced else {
          prompter.report(L10n.format(.alertCouldNotStop, ref.title))
          return
        }
        forced = await prompter.askToForceStop(title: ref.title)
        if forced {
          outcome = await terminator.forceStop(ref.target)
        } else {
          // Reuse Terminator's default 10-second grace period and identity recheck.
          outcome = await terminator.stop(ref.target)
        }
      }
    }
  }
}
