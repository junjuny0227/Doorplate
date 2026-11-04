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
        listeners: listeners,
        processes: Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) }),
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
      process(
        102, name: "java", path: "/usr/bin/java", args: ["java", "-jar", "/opt/app/app.jar"],
        cwd: "/scratch"),
      process(103, name: "caddy", path: "/opt/homebrew/bin/caddy"),
      process(104, name: "custom", path: nil),
    ]
    let entries = classify(
      records.map { Listener(pid: $0.pid, port: 8080, address: "::") }, processes: records,
      files: [
        "/Users/dev/shop/apps/site/package.json": "{\"name\":\"@shop/site\"}",
        "/Users/dev/shop/.git": "",
      ])
    #expect(entries.map(\.title) == ["@shop/site", "app.jar", "caddy", "custom"])
    #expect(entries.first?.directory == "/Users/dev/shop/apps/site")
    #expect(entries.first?.repositoryRoot == "/Users/dev/shop")
    #expect(entries.last?.directory == nil)
  }

  @Test func canTerminateRules() {
    let records = [
      process(101, uid: 502), process(102, hasStartTime: false),
      process(
        103, name: "ControlCenter",
        path: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"),
      process(104),
      process(
        105, name: "java", path: "/usr/bin/java",
        args: ["java", "org.gradle.launcher.daemon.bootstrap.GradleDaemon"]),
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
      process(
        900, name: "com.docker.backend",
        path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend"),
      process(901, name: "limactl", path: "/opt/homebrew/bin/limactl"),
      process(902, name: "Spotify", path: "/Applications/Spotify.app/Contents/MacOS/Spotify"),
    ]
    let entries = classify(
      records.map { Listener(pid: $0.pid, port: 52000, address: "::") }, processes: records)
    #expect(entries.count == 3)
    #expect(entries.allSatisfy { $0.section == .hidden(.otherApp) && !$0.canTerminate })
  }

  private var postgres: Container {
    Container(
      id: "3f2a9c1b7d4e0123456789", name: "/shop-postgres-1", image: "postgres:16-alpine",
      composeProject: "shop", composeService: "postgres", composeWorkingDir: "/Users/dev/shop",
      publishedPorts: [PortBinding(port: 5432, exposure: .network)], startedAt: startedAt)
  }

  private var redis: Container {
    Container(
      id: "abcdef1234567890", name: "/shop-redis-1", image: "redis:7",
      composeProject: "shop", composeService: "redis", composeWorkingDir: "/Users/dev/shop",
      publishedPorts: [PortBinding(port: 6379, exposure: .loopback)], startedAt: nil)
  }

  @Test func publishedPortsBecomeContainers() {
    let backend = process(
      900, name: "com.docker.backend",
      path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend")
    let entries = classify(
      [5432, 6379, 52000].map { Listener(pid: 900, port: UInt16($0), address: "::") },
      processes: [backend], containers: [postgres, redis])
    let docker = entries.filter { $0.section == .docker }
    #expect(docker.map(\.title) == ["postgres", "redis"])
    #expect(docker.map(\.tool) == ["shop-postgres-1", "shop-redis-1"])
    let remaining = entries.filter { $0.section != .docker }
    #expect(remaining.count == 1)
    #expect(remaining.first?.title == "Docker")
    #expect(remaining.first?.section == .hidden(.otherApp))
    #expect(remaining.first?.primary.port == 52000)
    #expect(remaining.first?.extras == [])
    // Port ownership is based on the published port set, not a runtime process name.
    #expect(
      classify(
        [Listener(pid: 101, port: 5432, address: "::")], processes: [process()],
        containers: [postgres]
      ).map(\.id) == ["docker:3f2a9c1b7d4e"])
  }

  @Test func containerWithoutCompose() throws {
    let container = Container(
      id: "nginx1234567890", name: "/hopeful_tesla", image: "library/nginx:1.27",
      publishedPorts: [PortBinding(port: 8080, exposure: .network)])
    let entry = try #require(classify([], processes: [], containers: [container]).first)
    #expect(entry.title == "hopeful_tesla")
    #expect(entry.tool == "nginx")
    #expect(entry.directory == nil)
    #expect(entry.repositoryRoot == nil)
    #expect(entry.likelyHTTP)
  }

  @Test func containerEntryFields() throws {
    let entries = classify([], processes: [], containers: [postgres, redis])
    let entry = try #require(entries.first)
    #expect(entry.id == "docker:3f2a9c1b7d4e")
    #expect(entry.target == .container(id: postgres.id))
    #expect(entry.section == .docker)
    #expect(entry.title == "postgres")
    #expect(entry.tool == "shop-postgres-1")
    #expect(entry.image == "postgres:16-alpine")
    #expect(entry.directory == "/Users/dev/shop")
    #expect(entry.repositoryRoot == nil)
    #expect(entry.primary == PortBinding(port: 5432, exposure: .network))
    #expect(entry.extras.isEmpty)
    #expect(entry.startedAt == startedAt)
    #expect(!entry.isLongRunning)
    #expect(!entry.likelyHTTP)
    #expect(entry.canTerminate)
    #expect(entries.last?.primary.exposure == .loopback)
    #expect(entries.last?.startedAt == nil)
    #expect(entries.last?.canTerminate == true)
  }

  @Test func containerPortsAreSortedAndUnpublishedContainersAreSkipped() throws {
    var container = postgres
    container.publishedPorts = [
      PortBinding(port: 9000, exposure: .loopback, role: .inspector),
      PortBinding(port: 8080, exposure: .network),
    ]
    var unpublished = redis
    unpublished.publishedPorts = []
    let entries = classify([], processes: [], containers: [container, unpublished])
    #expect(entries.count == 1)
    let entry = try #require(entries.first)
    #expect(entry.primary == PortBinding(port: 8080, exposure: .network))
    #expect(entry.extras == [PortBinding(port: 9000, exposure: .loopback)])
    #expect(!entry.likelyHTTP)
  }

  @Test func sharedSocketBelongsToTopmostAncestor() {
    let records = [process(200, parent: 1), process(201, parent: 200), process(202, parent: 200)]
    let shared = records.reversed().map {
      Listener(pid: $0.pid, port: 8000, address: "::", socketID: 77)
    }
    let entries = classify(shared, processes: records)
    #expect(entries.map(\.id) == ["pid:200"])
    let withWorkerSocket = classify(
      shared + [Listener(pid: 201, port: 9000, address: "::1", socketID: 78)], processes: records)
    #expect(withWorkerSocket.map(\.id) == ["pid:200", "pid:201"])
    #expect(withWorkerSocket.map { $0.primary.port } == [8000, 9000])
    #expect(withWorkerSocket.first?.target == .process(pid: 200, startedAt: startedAt))
  }

  @Test func unrelatedSharersPickSmallestPid() {
    let entries = classify(
      [
        Listener(pid: 301, port: 8000, address: "::", socketID: 77),
        Listener(pid: 300, port: 8000, address: "::", socketID: 77),
      ],
      processes: [process(301, parent: 1), process(300, parent: 2)])
    #expect(entries.map(\.id) == ["pid:300"])
  }

  @Test func unknownSocketIDsKeepSeparateOwners() {
    let entries = classify(
      [
        Listener(pid: 200, port: 8000, address: "::"),
        Listener(pid: 201, port: 8000, address: "::"),
      ],
      processes: [process(200, parent: 1), process(201, parent: 200)])
    #expect(entries.map(\.id) == ["pid:200", "pid:201"])
  }

  @Test func vanishedProcessIsSkipped() {
    let entries = classify(
      [
        Listener(pid: 999, port: 3000, address: "::"),
        Listener(pid: 101, port: 8080, address: "::"),
      ],
      processes: [process()])
    #expect(entries.map(\.id) == ["pid:101"])
  }
}
