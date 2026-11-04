import DoorplateCore
import Foundation
import Testing

struct ModelTests {
  @Test(arguments: [
    ("127.0.0.1", Exposure.loopback), ("::1", .loopback),
    ("::ffff:127.0.0.1", .loopback), ("0.0.0.0", .network),
    ("::", .network), ("192.168.0.10", .network),
  ])
  func exposureFromAddress(address: String, expected: Exposure) {
    #expect(Listener(pid: 1, port: 80, address: address).exposure == expected)
  }

  @Test func optionalFixtureFieldsAndDockerStates() throws {
    for status in [DockerStatus.absent, .notResponding] {
      let json = """
        {"now":"2026-11-04T06:00:00Z","home":"/Users/dev","currentUID":501,
         "settings":{"longRunningThreshold":86400,"showDevTools":false,"showOtherApps":false},
         "listeners":[{"pid":1,"port":80,"address":"::1"}],"processes":[],"files":{},
         "docker":{"status":"\(status.rawValue)"}}
        """
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let fixture = try decoder.decode(ScanFixture.self, from: Data(json.utf8))
      #expect(fixture.denied.isEmpty)
      #expect(fixture.listeners.first?.socketID == nil)
      #expect(fixture.docker.containers == nil)
      #expect(fixture.docker.status == status)
    }
  }

  @Test func defaultsAndAssociatedValuesRoundTrip() throws {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(SnapshotSettings().longRunningThreshold == 86_400)
    #expect(!SnapshotSettings().showDevTools)
    #expect(!SnapshotSettings().showOtherApps)
    #expect(Snapshot.empty(at: now).scannedAt == now)
    #expect(Snapshot.empty(at: now).badgeCount == 0)
    let entries = [
      ServerEntry(
        id: "pid:1", target: .process(pid: 1, startedAt: now),
        section: .hidden(.devTool), title: "node",
        primary: PortBinding(port: 80, exposure: .loopback),
        likelyHTTP: true, canTerminate: true),
      ServerEntry(
        id: "docker:abc", target: .container(id: "abc"),
        section: .docker, title: "redis", image: "redis:7",
        primary: PortBinding(port: 6379, exposure: .network),
        likelyHTTP: false, canTerminate: true),
    ]
    let data = try JSONEncoder().encode(entries)
    #expect(try JSONDecoder().decode([ServerEntry].self, from: data) == entries)
  }

  @Test func fakeFileProbeHonorsDeniedBoundaries() {
    let files = FakeFileProbe(
      files: ["/a": "text", "/d/file": "private", "/dog": "ok"], denied: ["/d"])
    #expect(files.presence("/a") == .present)
    #expect(files.read("/a") == "text")
    #expect(files.presence("/missing") == .absent)
    #expect(files.read("/missing") == nil)
    #expect(files.presence("/d") == .denied)
    #expect(files.presence("/d/file") == .denied)
    #expect(files.read("/d/file") == nil)
    #expect(files.presence("/dog") == .present)
    #expect(FakeFileProbe(denied: ["/"]).presence("/any") == .denied)
    #expect(FakeFileProbe(denied: ["/d/"]).presence("/d/file") == .denied)
  }

  @Test func fakeProcessSourceSupportsFailuresAndUpdates() throws {
    let record = ProcessRecord(pid: 1, name: "node")
    let source = FakeProcessSource(
      listeners: [Listener(pid: 1, port: 80, address: "::1")], processes: [record])
    #expect(source.process(1) == record)
    #expect(source.process(2) == nil)
    #expect(try source.listeners().count == 1)
    source.failing = true
    #expect(throws: FakeProcessSource.Failure.self) { try source.listeners() }
    source.failing = false
    source.listenerRecords = []
    source.records = [:]
    #expect(try source.listeners().isEmpty)
    #expect(source.process(1) == nil)
  }

  @Test func fakeDockerAndSignalerRecordCalls() async throws {
    let docker = FakeDockerSource()
    #expect(try await docker.containers().isEmpty)
    try await docker.stop("abc")
    #expect(docker.stopped == ["abc"])
    docker.result = .failure(.absent)
    do {
      _ = try await docker.containers()
      Issue.record("Expected absent")
    } catch { #expect(error == .absent) }
    docker.stopResult = .failure(.api(status: 404, message: "missing"))
    do {
      try await docker.stop("def")
      Issue.record("Expected API failure")
    } catch { #expect(error == .api(status: 404, message: "missing")) }
    #expect(docker.stopped == ["abc", "def"])
    let now = Date(timeIntervalSince1970: 1_000)
    let signaler = FakeSignaler(startTimes: [1: now], exits: false, forcedResult: .notPermitted)
    #expect(signaler.startTime(of: 1) == now)
    #expect(signaler.startTime(of: 2) == nil)
    #expect(signaler.signal(15, to: 1) == .notPermitted)
    #expect(signaler.signals == [15])
    #expect(signaler.sentSignals == [.init(signal: 15, pid: 1)])
    #expect(await !signaler.waitForExit(of: 1, timeout: .seconds(10)))
    #expect(signaler.waits == [.init(pid: 1, timeout: .seconds(10))])
    signaler.startTimes = [:]
    signaler.exits = true
    signaler.forcedResult = nil
    #expect(signaler.startTime(of: 1) == nil)
    #expect(signaler.signal(9, to: 1) == .sent)
    #expect(await signaler.waitForExit(of: 1, timeout: .seconds(1)))
    #expect(
      Fixtures.url("scenarios/test.json").path.hasSuffix("/Tests/Fixtures/scenarios/test.json"))
  }

  @Test func scanFixtureRoundTrips() throws {
    let json = #"""
      { "now": "2026-11-04T06:00:00Z", "home": "/Users/dev", "currentUID": 501,
        "settings": { "longRunningThreshold": 86400, "showDevTools": false, "showOtherApps": false },
        "listeners": [ { "pid": 101, "port": 5173, "address": "::1", "socketID": 4097 } ],
        "processes": [ { "pid": 101, "name": "node", "executablePath": "/opt/homebrew/bin/node",
          "arguments": ["node", "/Users/dev/repot/node_modules/.bin/vite"],
          "cwd": "/Users/dev/repot/apps/desktop", "parentPID": 100,
          "startedAt": "2026-11-04T05:20:00Z", "uid": 501 } ],
        "files": { "/Users/dev/repot/apps/desktop/package.json": "{\"name\":\"@repot/desktop\"}",
                   "/Users/dev/repot/.git": "" },
        "denied": [ "/Users/dev/Documents" ],
        "docker": { "status": "ok", "containers": [] } }
      """#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let fixture = try decoder.decode(ScanFixture.self, from: Data(json.utf8))
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    #expect(try decoder.decode(ScanFixture.self, from: encoder.encode(fixture)) == fixture)
    #expect(fixture.docker.status == .ok)
    #expect(fixture.listeners.first?.socketID == 4097)
  }
}
