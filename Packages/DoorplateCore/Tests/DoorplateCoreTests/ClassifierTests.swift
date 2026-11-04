import DoorplateCore
import Foundation
import Testing

struct ClassifierTests {
  private let startedAt = Date(timeIntervalSince1970: 1_700_000_000)

  private func process(
    _ pid: Int32 = 101, name: String = "node", path: String? = "/opt/homebrew/bin/node",
    args: [String]? = nil, cwd: String? = nil, parent: Int32? = nil,
    uid: UInt32? = 501, hasStartTime: Bool = true
  ) -> ProcessRecord {
    ProcessRecord(
      pid: pid, name: name, executablePath: path, arguments: args, cwd: cwd,
      parentPID: parent, startedAt: hasStartTime ? startedAt : nil, uid: uid)
  }

  private func classify(
    _ listeners: [Listener], processes: [ProcessRecord], containers: [Container] = [],
    files: [String: String] = [:]
  ) -> [ServerEntry] {
    Classifier(resolver: ProjectResolver(files: FakeFileProbe(files: files)), currentUID: 501)
      .classify(
        listeners: listeners, processes: Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) }),
        containers: containers)
  }

  @Test func groupsPortsByProcess() throws {
    let entries = classify(
      [
        Listener(pid: 101, port: 5173, address: "::1"),
        Listener(pid: 101, port: 5173, address: "127.0.0.1"),
        Listener(pid: 101, port: 24678, address: "::1"),
      ], processes: [process()])
    #expect(entries.count == 1)
    let entry = try #require(entries.first)
    #expect(entry.id == "pid:101")
    #expect(entry.target == .process(pid: 101, startedAt: startedAt))
    #expect(entry.primary == PortBinding(port: 5173, exposure: .loopback))
    #expect(entry.extras == [PortBinding(port: 24678, exposure: .loopback)])
    #expect(entry.tool == "node")
    #expect(entry.image == nil)
    #expect(entry.startedAt == startedAt)
    #expect(!entry.isLongRunning)
    #expect(entry.likelyHTTP)
  }

  @Test func titleFallbacks() {
    let records = [
      process(101, cwd: "/Users/dev/shop/apps/site"),
      process(102, name: "java", path: "/usr/bin/java", args: ["java", "-jar", "/opt/app/app.jar"], cwd: "/scratch"),
      process(103, name: "caddy", path: "/opt/homebrew/bin/caddy"),
      process(104, name: "custom", path: nil),
    ]
    let entries = classify(
      records.map { Listener(pid: $0.pid, port: 8080, address: "::") }, processes: records,
      files: ["/Users/dev/shop/apps/site/package.json": "{\"name\":\"@shop/site\"}", "/Users/dev/shop/.git": ""])
    #expect(entries.map(\.title) == ["@shop/site", "app.jar", "caddy", "custom"])
    #expect(entries.first?.directory == "/Users/dev/shop/apps/site")
    #expect(entries.first?.repositoryRoot == "/Users/dev/shop")
    #expect(entries.last?.directory == nil)
  }

  @Test func canTerminateRules() {
    let records = [
      process(101, uid: 502), process(102, hasStartTime: false),
      process(103, name: "ControlCenter", path: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"),
      process(104),
      process(105, name: "java", path: "/usr/bin/java", args: ["java", "org.gradle.launcher.daemon.bootstrap.GradleDaemon"]),
      process(106, uid: nil),
    ]
    let entries = classify(
      records.map { Listener(pid: $0.pid, port: 5000, address: "::") }, processes: records)
    #expect(entries.map(\.canTerminate) == [false, false, false, true, true, false])
    #expect(entries[2].section == .system)
    #expect(entries[2].title == "AirPlay Receiver (macOS)")
    #expect(entries[4].section == .hidden(.devTool))
  }

  @Test func runtimeAndOtherAppsAreNeverTerminable() {
    let records = [
      process(900, name: "com.docker.backend", path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend"),
      process(901, name: "limactl", path: "/opt/homebrew/bin/limactl"),
      process(902, name: "Spotify", path: "/Applications/Spotify.app/Contents/MacOS/Spotify"),
    ]
    let entries = classify(
      records.map { Listener(pid: $0.pid, port: 52000, address: "::") }, processes: records)
    #expect(entries.count == 3)
    #expect(entries.allSatisfy { $0.section == .hidden(.otherApp) && !$0.canTerminate })
  }

  @Test func vanishedProcessIsSkipped() {
    let entries = classify(
      [Listener(pid: 999, port: 3000, address: "::"), Listener(pid: 101, port: 8080, address: "::")],
      processes: [process()])
    #expect(entries.map(\.id) == ["pid:101"])
  }
}
