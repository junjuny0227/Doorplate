import Darwin
import Foundation
import Testing

@testable import DoorplateCore

struct DockerTests {
  private final class InspectGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var arrivals = 0
    private var timedOut = false
    var concurrent: Bool {
      condition.lock()
      defer { condition.unlock() }
      return arrivals == 2 && !timedOut
    }
    func arrive() {
      condition.lock()
      defer { condition.unlock() }
      arrivals += 1
      condition.broadcast()
      let deadline = Date().addingTimeInterval(0.5)
      while arrivals < 2 {
        if !condition.wait(until: deadline) {
          timedOut = true
          break
        }
      }
    }
  }

  @Test func inspectsConcurrentlyAndPreservesListOrder() async throws {
    let body = Data(#"[{"Id":"first","Image":"nginx"},{"Id":"second","Image":"redis"}]"#.utf8)
    let gate = InspectGate()
    let server = try UnixTestServer(
      .responses { request in
        if request == "GET /containers/json HTTP/1.1" { return UnixTestServer.Response(body: body) }
        gate.arrive()
        return UnixTestServer.Response(
          body: Data(#"{"State":{"StartedAt":"2026-11-04T05:00:00Z"}}"#.utf8))
      })
    let result = try await UnixSocketDockerSource(candidatePaths: [server.path]).containers()
    #expect(gate.concurrent)
    #expect(result.map(\.id) == ["first", "second"])
    #expect(result.allSatisfy { $0.startedAt != nil })
  }

  @Test(arguments: [204, 304, 404, 200])
  func stopStatuses(status: Int) async throws {
    let server = try UnixTestServer(
      .responses { _ in
        UnixTestServer.Response(
          status: status, body: Data(#"{"message":"no such container"}"#.utf8))
      })
    let source = UnixSocketDockerSource(candidatePaths: [server.path])
    if status == 204 || status == 304 {
      try await source.stop("abc")
    } else {
      await #expect(throws: DockerError.api(status: status, message: "no such container")) {
        try await source.stop("abc")
      }
    }
    #expect(server.requests == ["POST /containers/abc/stop?t=10 HTTP/1.1"])
  }

  @Test func stopWaitsLongerThanListTimeout() async throws {
    let server = try UnixTestServer(
      .responses { _ in
        UnixTestServer.Response(status: 204, delay: 2)
      })
    let source = UnixSocketDockerSource(
      candidatePaths: [server.path], timeout: .seconds(1), stopTimeout: .seconds(5))
    try await source.stop("abc")
    await #expect(throws: DockerError.notResponding) { try await source.containers() }
  }

  @Test func stopTimeoutIsNotResponding() async throws {
    let server = try UnixTestServer(.silent)
    let source = UnixSocketDockerSource(
      candidatePaths: [server.path], stopTimeout: .milliseconds(50))
    await #expect(throws: DockerError.notResponding) { try await source.stop("abc") }
  }

  @Test func firstConnectedCandidateIsAuthoritative() async throws {
    let first = try UnixTestServer(.responses { _ in UnixTestServer.Response(status: 503) })
    let next = try UnixTestServer(
      .responses { _ in UnixTestServer.Response(body: Data("[]".utf8)) })
    await #expect(throws: DockerError.api(status: 503, message: "")) {
      try await UnixSocketDockerSource(candidatePaths: [first.path, next.path]).containers()
    }
    #expect(next.requests.isEmpty)
  }

  @Test func defaultCandidateOrder() {
    #expect(
      UnixSocketDockerSource.defaultPaths(home: "/Users/dev") == [
        "/Users/dev/.docker/run/docker.sock", "/var/run/docker.sock",
        "/Users/dev/.orbstack/run/docker.sock", "/Users/dev/.colima/default/docker.sock",
      ])
  }

  @Test func noSocketIsAbsent() async {
    await #expect(throws: DockerError.absent) {
      try await UnixSocketDockerSource(candidatePaths: [UnixTestServer.unusedPath()]).containers()
    }
  }

  @Test func refusedSocketIsAbsent() async throws {
    let server = try UnixTestServer(.refused)
    await #expect(throws: DockerError.absent) {
      try await UnixSocketDockerSource(candidatePaths: [server.path]).containers()
    }
  }

  @Test func danglingSymlinkIsAbsent() async throws {
    let path = UnixTestServer.unusedPath()
    try FileManager.default.createSymbolicLink(
      atPath: path, withDestinationPath: UnixTestServer.unusedPath())
    defer { try? FileManager.default.removeItem(atPath: path) }
    await #expect(throws: DockerError.absent) {
      try await UnixSocketDockerSource(candidatePaths: [path]).containers()
    }
  }

  @Test func silentServerIsNotResponding() async throws {
    let server = try UnixTestServer(.silent)
    let start = ContinuousClock.now
    await #expect(throws: DockerError.notResponding) {
      try await UnixSocketDockerSource(candidatePaths: [server.path]).containers()
    }
    #expect(start.duration(to: .now) < .milliseconds(1500))
  }

  @Test func servesContainersWithStartedAt() async throws {
    let list = try DockerJSON.containers(Data(contentsOf: Fixtures.url("docker/containers.json")))
    let postgres = try #require(list.first { $0.composeService == "postgres" })
    let rawList =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: Fixtures.url("docker/containers.json"))) as! [[String: Any]]
    let body = try JSONSerialization.data(
      withJSONObject: rawList.filter { $0["Id"] as? String == postgres.id })
    let inspect = try Data(contentsOf: Fixtures.url("docker/inspect-postgres.json"))
    let server = try UnixTestServer(
      .responses { request in
        UnixTestServer.Response(
          body: request == "GET /containers/json HTTP/1.1" ? body : inspect, chunked: true,
          fragmentSize: 7)
      })
    let refused = try UnixTestServer(.refused)
    let source = UnixSocketDockerSource(candidatePaths: [
      UnixTestServer.unusedPath(), refused.path, server.path,
    ])
    let result = try await source.containers()
    #expect(result.count == 1)
    #expect(result.first?.id == postgres.id)
    #expect(result.first?.startedAt == (try DockerJSON.startedAt(inspect)))
    #expect(result.first?.startedAt != nil)
    #expect(server.requests.contains("GET /containers/\(postgres.id)/json HTTP/1.1"))
  }

  @Test func listAPIErrorPreservesMessage() async throws {
    let server = try UnixTestServer(
      .responses { _ in
        UnixTestServer.Response(status: 500, body: Data(#"{"message":"engine unavailable"}"#.utf8))
      })
    await #expect(throws: DockerError.api(status: 500, message: "engine unavailable")) {
      try await UnixSocketDockerSource(candidatePaths: [server.path]).containers()
    }
  }

  @Test func inspectFailureKeepsContainer() async throws {
    let body = Data(#"[{"Id":"x","Names":["/x"],"Image":"nginx","Ports":[]}]"#.utf8)
    let server = try UnixTestServer(
      .responses { request in
        request == "GET /containers/json HTTP/1.1"
          ? UnixTestServer.Response(body: body) : UnixTestServer.Response(status: 404)
      })
    let result = try await UnixSocketDockerSource(candidatePaths: [server.path]).containers()
    #expect(result.count == 1)
    #expect(result.first?.startedAt == nil)
  }

  @Test func decodesComposeContainers() throws {
    let containers = try DockerJSON.containers(
      Data(contentsOf: Fixtures.url("docker/containers.json")))
    let postgres = try #require(containers.first { $0.composeService == "postgres" })
    #expect(postgres.composeProject == "doorplate-spike")
    #expect(postgres.name == "/doorplate-spike-postgres-1")
    #expect(postgres.image == "postgres:16-alpine")
    #expect(postgres.composeWorkingDir == "/Users/dev/Documents/Doorplate-wt/t4/spikes/docker")
    #expect(postgres.publishedPorts == [PortBinding(port: 55432, exposure: .network, role: nil)])
    let redis = try #require(containers.first { $0.composeService == "redis" })
    #expect(redis.publishedPorts == [PortBinding(port: 56379, exposure: .loopback, role: nil)])
  }

  @Test func publishedPortsFilterSortAndMerge() throws {
    let json = Data(
      #"[{"Id":"x","Names":["/x"],"Image":"nginx","Ports":[{"Type":"udp","PublicPort":1},{"Type":"tcp","PrivatePort":80},{"Type":"tcp","PublicPort":9000,"IP":"::1"},{"Type":"tcp","PublicPort":9000,"IP":"0.0.0.0"},{"Type":"tcp","PublicPort":8000,"IP":"::1"},{"Type":"tcp","PublicPort":7000}]}]"#
        .utf8)
    let container = try #require(DockerJSON.containers(json).first)
    #expect(container.composeProject == nil)
    #expect(
      container.publishedPorts == [
        PortBinding(port: 7000, exposure: .network, role: nil),
        PortBinding(port: 8000, exposure: .loopback, role: nil),
        PortBinding(port: 9000, exposure: .network, role: nil),
      ])
  }

  @Test func parsesNanosecondStartedAt() throws {
    let date = try #require(
      try DockerJSON.startedAt(
        Data(#"{"State":{"StartedAt":"2026-11-04T05:00:00.123456789Z"}}"#.utf8)))
    let expected = try #require(ISO8601DateFormatter().date(from: "2026-11-04T05:00:00Z"))
    #expect(abs(date.timeIntervalSince(expected) - 0.123) < 0.000001)
    #expect(
      try DockerJSON.startedAt(Data(#"{"State":{"StartedAt":"0001-01-01T00:00:00Z"}}"#.utf8)) == nil
    )
    #expect(
      try DockerJSON.startedAt(Data(contentsOf: Fixtures.url("docker/inspect-postgres.json")))
        != nil)
  }

  @Test func parsesContentLengthAndChunked() throws {
    let body = Data("hello π".utf8)
    let length = Data("HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n".utf8) + body
    let chunked = Data(
      "HTTP/1.1 200 OK\r\ntRaNsFeR-EnCoDiNg: chunked\r\n\r\n4;ext=yes\r\nhell\r\n4\r\no π\r\n0\r\nX-Trailer: yes\r\n\r\n"
        .utf8)
    #expect(try HTTPResponse.parse(length).body == body)
    #expect(try HTTPResponse.parse(chunked).body == body)
    let eof = try HTTPResponse.parse(Data("HTTP/1.1 404 Not Found\r\n\r\nmissing".utf8))
    #expect(eof.status == 404)
    #expect(eof.body == Data("missing".utf8))
  }

  @Test(arguments: [
    "garbage", "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nx",
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n-1\r\nx\r\n",
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nx",
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n",
  ])
  func rejectsMalformedHTTP(wire: String) {
    #expect(throws: (any Error).self) { try HTTPResponse.parse(Data(wire.utf8)) }
  }
}
