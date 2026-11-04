import Darwin
import DoorplateCore
import Foundation
import Testing

struct TerminatorTests {
  private let started = Date(timeIntervalSince1970: 1_000)
  private let pid: Int32 = 101

  @Test func gracefulStop() async {
    let signaler = FakeSignaler(startTimes: [pid: started])
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    #expect(await terminator.stop(.process(pid: pid, startedAt: started)) == .stopped)
    #expect(signaler.signals == [SIGTERM])
    #expect(signaler.waits == [.init(pid: pid, timeout: .seconds(10))])
  }

  @Test func stillRunningAfterGrace() async {
    let signaler = FakeSignaler(startTimes: [pid: started], exits: false)
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource(), gracePeriod: .seconds(2))
    #expect(await terminator.stop(.process(pid: pid, startedAt: started)) == .stillRunning)
    #expect(signaler.signals == [SIGTERM])
    #expect(signaler.waits == [.init(pid: pid, timeout: .seconds(2))])
  }

  @Test func forceStopRechecksIdentity() async {
    let signaler = FakeSignaler(startTimes: [pid: started], exits: false)
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    #expect(await terminator.stop(.process(pid: pid, startedAt: started)) == .stillRunning)
    signaler.startTimes[pid] = started.addingTimeInterval(1)
    #expect(await terminator.forceStop(.process(pid: pid, startedAt: started)) == .alreadyGone)
    #expect(signaler.signals == [SIGTERM])
  }

  @Test func forceStopKills() async {
    let signaler = FakeSignaler(startTimes: [pid: started])
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    #expect(await terminator.forceStop(.process(pid: pid, startedAt: started)) == .stopped)
    #expect(signaler.signals == [SIGKILL])
    #expect(signaler.waits == [.init(pid: pid, timeout: .seconds(1))])
  }

  @Test func forceStopTimeoutIsStillRunning() async {
    let signaler = FakeSignaler(startTimes: [pid: started], exits: false)
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    #expect(await terminator.forceStop(.process(pid: pid, startedAt: started)) == .stillRunning)
    #expect(signaler.signals == [SIGKILL])
  }

  @Test(arguments: [false, true]) func notPermittedSignal(force: Bool) async {
    let signaler = FakeSignaler(startTimes: [pid: started], forcedResult: .notPermitted)
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    let target = Target.process(pid: pid, startedAt: started)
    let outcome = force ? await terminator.forceStop(target) : await terminator.stop(target)
    #expect(outcome == .notPermitted)
    #expect(signaler.waits.isEmpty)
  }

  @Test(arguments: [false, true]) func unknownStartTimeIsNotPermitted(force: Bool) async {
    let signaler = FakeSignaler(startTimes: [pid: started])
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    let target = Target.process(pid: pid, startedAt: nil)
    let outcome = force ? await terminator.forceStop(target) : await terminator.stop(target)
    #expect(outcome == .notPermitted)
    #expect(signaler.signals.isEmpty)
  }

  @Test func containerStop() async {
    let docker = FakeDockerSource()
    let signaler = FakeSignaler()
    let terminator = Terminator(signaler: signaler, docker: docker)
    #expect(await terminator.stop(.container(id: "test")) == .stopped)
    docker.stopResult = .failure(.api(status: 404, message: "no such container"))
    guard case .failed(let message) = await terminator.stop(.container(id: "missing")) else {
      Issue.record("Expected Docker stop failure")
      return
    }
    #expect(message.contains("no such container"))
    #expect(docker.stopped == ["test", "missing"])
    guard case .failed = await terminator.forceStop(.container(id: "test")) else {
      Issue.record("Force stop must reject containers")
      return
    }
    #expect(docker.stopped == ["test", "missing"])
    #expect(signaler.signals.isEmpty)
  }

  @Test(arguments: [false, true]) func vanishedProcessIsAlreadyGone(force: Bool) async {
    let signaler = FakeSignaler()
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    let target = Target.process(pid: pid, startedAt: started)
    let outcome = force ? await terminator.forceStop(target) : await terminator.stop(target)
    #expect(outcome == .alreadyGone)
    #expect(signaler.signals.isEmpty)
    signaler.startTimes[pid] = started
    signaler.forcedResult = .noSuchProcess
    let raced = force ? await terminator.forceStop(target) : await terminator.stop(target)
    #expect(raced == .alreadyGone)
    #expect(signaler.waits.isEmpty)
  }

  @Test func startTimeWithinOneMillisecondMatches() async {
    let signaler = FakeSignaler(startTimes: [pid: started.addingTimeInterval(0.0005)])
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    #expect(await terminator.stop(.process(pid: pid, startedAt: started)) == .stopped)
    #expect(signaler.signals == [SIGTERM])
  }

  @Test func pidReuseIsAlreadyGone() async {
    let signaler = FakeSignaler(startTimes: [pid: started.addingTimeInterval(1)])
    let terminator = Terminator(signaler: signaler, docker: FakeDockerSource())
    #expect(await terminator.stop(.process(pid: pid, startedAt: started)) == .alreadyGone)
    #expect(signaler.signals.isEmpty)
  }
}
