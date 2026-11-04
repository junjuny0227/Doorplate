import Darwin
import DoorplateCore
import Foundation
import Testing

@testable import DoorplateMenu

@MainActor struct StopCoordinatorTests {
  private let ref = EntryRef(
    id: "pid:101", target: .process(pid: 101, startedAt: Date(timeIntervalSince1970: 1_000)),
    title: "shop-api", port: 8080)

  @Test func stopsGracefully() async {
    let signaler = FakeSignaler()
    let prompter = FakePrompter()
    var changes = 0
    var states: [Set<String>] = []
    var coordinator: StopCoordinator!
    coordinator = StopCoordinator(
      terminator: Terminator(signaler: signaler, docker: FakeDocker(), gracePeriod: .milliseconds(10)),
      prompter: prompter,
      onChange: {
        changes += 1
        states.append(coordinator.stopping)
      })
    await coordinator.stop(ref)
    #expect(coordinator.stopping.isEmpty)
    #expect(changes == 2)
    #expect(states == [[ref.id], []])
    #expect(signaler.signals == [.init(value: SIGTERM, pid: 101)])
    #expect(signaler.waits == [.init(pid: 101, timeout: .milliseconds(10))])
    #expect(prompter.titles.isEmpty && prompter.messages.isEmpty && prompter.beepCount == 0)
  }

  @Test func alreadyGoneBeeps() async {
    let signaler = FakeSignaler(startedAt: Date(timeIntervalSince1970: 2_000))
    let prompter = FakePrompter()
    var events: [String] = []
    prompter.onBeep = { events.append("beep") }
    let coordinator = StopCoordinator(
      terminator: Terminator(signaler: signaler, docker: FakeDocker()), prompter: prompter,
      onChange: { events.append("refresh") })
    await coordinator.stop(ref)
    #expect(prompter.beepCount == 1)
    #expect(events == ["refresh", "beep", "refresh"])
    #expect(signaler.signals.isEmpty && signaler.waits.isEmpty)
    #expect(prompter.messages.isEmpty && prompter.titles.isEmpty)
    #expect(coordinator.stopping.isEmpty)
  }

  @Test func stillRunningThenForce() async {
    let signaler = FakeSignaler(exits: [false, true])
    let prompter = FakePrompter()
    prompter.answers = [true]
    let coordinator = make(signaler, prompter)
    await coordinator.stop(ref)
    #expect(signaler.signals == [.init(value: SIGTERM, pid: 101), .init(value: SIGKILL, pid: 101)])
    #expect(signaler.waits.map(\.timeout) == [.milliseconds(10), .seconds(1)])
    #expect(prompter.titles == ["shop-api"])
    #expect(prompter.messages.isEmpty && coordinator.stopping.isEmpty)
  }

  @Test func keepWaitingRetries() async {
    let signaler = FakeSignaler(exits: [false, true])
    let prompter = FakePrompter()
    prompter.answers = [false]
    // Use the production default: each wait, including the retry, is another 10 seconds.
    let coordinator = StopCoordinator(
      terminator: Terminator(signaler: signaler, docker: FakeDocker()), prompter: prompter,
      onChange: {})
    await coordinator.stop(ref)
    #expect(prompter.titles == ["shop-api"])
    #expect(signaler.signals == [.init(value: SIGTERM, pid: 101), .init(value: SIGTERM, pid: 101)])
    #expect(signaler.waits.map(\.timeout) == [.seconds(10), .seconds(10)])
    #expect(prompter.messages.isEmpty && coordinator.stopping.isEmpty)
  }

  @Test func forceFailsReportsCouldNotStop() async {
    let signaler = FakeSignaler(exits: [false, false])
    let prompter = FakePrompter()
    let coordinator = make(signaler, prompter)
    await coordinator.stop(ref)
    #expect(prompter.messages == [L10n.format(.alertCouldNotStop, "shop-api")])
    #expect(prompter.titles == ["shop-api"])
    #expect(signaler.signals.map(\.value) == [SIGTERM, SIGKILL])
    #expect(coordinator.stopping.isEmpty)
  }

  @Test func notPermittedReports() async {
    let signaler = FakeSignaler(result: .notPermitted)
    let prompter = FakePrompter()
    let coordinator = make(signaler, prompter)
    await coordinator.stop(ref)
    #expect(prompter.messages == [L10n.text(.alertNotPermitted)])
    #expect(signaler.waits.isEmpty && prompter.titles.isEmpty)
    #expect(coordinator.stopping.isEmpty)
  }

  @Test func dockerFailureReports() async {
    let docker = FakeDocker(error: .api(status: 404, message: "no such container"))
    let signaler = FakeSignaler()
    let prompter = FakePrompter()
    let coordinator = StopCoordinator(
      terminator: Terminator(signaler: signaler, docker: docker), prompter: prompter, onChange: {})
    await coordinator.stop(EntryRef(id: "docker:missing", target: .container(id: "missing"), title: "db", port: 5432))
    #expect(await docker.stopped == ["missing"])
    #expect(prompter.messages.count == 1)
    #expect(prompter.messages.first?.contains("no such container") == true)
    #expect(signaler.signals.isEmpty && prompter.titles.isEmpty)
    #expect(coordinator.stopping.isEmpty)
  }

  @Test func secondStopWhileStoppingIsIgnored() async {
    let signaler = FakeSignaler(exits: [false, true])
    let prompter = FakePrompter()
    prompter.suspendPrompt = true
    var changes = 0
    let coordinator = StopCoordinator(
      terminator: Terminator(signaler: signaler, docker: FakeDocker(), gracePeriod: .milliseconds(10)),
      prompter: prompter, onChange: { changes += 1 })
    let first = Task { await coordinator.stop(ref) }
    await prompter.waitUntilAsked()
    #expect(coordinator.stopping == [ref.id])
    let signals = signaler.signals
    await coordinator.stop(ref)
    #expect(signaler.signals == signals)
    #expect(prompter.titles == ["shop-api"])
    #expect(changes == 1)
    #expect(coordinator.stopping == [ref.id])
    prompter.answer(true)
    await first.value
    #expect(signaler.signals.map(\.value) == [SIGTERM, SIGKILL])
    #expect(changes == 2 && coordinator.stopping.isEmpty)
  }

  private func make(_ signaler: FakeSignaler, _ prompter: FakePrompter) -> StopCoordinator {
    StopCoordinator(
      terminator: Terminator(signaler: signaler, docker: FakeDocker(), gracePeriod: .milliseconds(10)),
      prompter: prompter, onChange: {})
  }
}
