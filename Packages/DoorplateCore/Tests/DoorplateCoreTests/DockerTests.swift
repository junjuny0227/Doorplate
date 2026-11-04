import Darwin
import Foundation
import Testing

@testable import DoorplateCore

struct DockerTests {
  @Test func decodesComposeContainers() throws {
    let containers = try DockerJSON.containers(Data(contentsOf: Fixtures.url("docker/containers.json")))
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
    let json = Data(#"[{"Id":"x","Names":["/x"],"Image":"nginx","Ports":[{"Type":"udp","PublicPort":1},{"Type":"tcp","PrivatePort":80},{"Type":"tcp","PublicPort":9000,"IP":"::1"},{"Type":"tcp","PublicPort":9000,"IP":"0.0.0.0"},{"Type":"tcp","PublicPort":8000,"IP":"::1"},{"Type":"tcp","PublicPort":7000}]}]"#.utf8)
    let container = try #require(DockerJSON.containers(json).first)
    #expect(container.composeProject == nil)
    #expect(container.publishedPorts == [
      PortBinding(port: 7000, exposure: .network, role: nil),
      PortBinding(port: 8000, exposure: .loopback, role: nil),
      PortBinding(port: 9000, exposure: .network, role: nil)
    ])
  }

  @Test func parsesNanosecondStartedAt() throws {
    let date = try #require(try DockerJSON.startedAt(Data(#"{"State":{"StartedAt":"2026-11-04T05:00:00.123456789Z"}}"#.utf8)))
    let expected = try #require(ISO8601DateFormatter().date(from: "2026-11-04T05:00:00Z"))
    #expect(abs(date.timeIntervalSince(expected) - 0.123) < 0.000001)
    #expect(try DockerJSON.startedAt(Data(#"{"State":{"StartedAt":"0001-01-01T00:00:00Z"}}"#.utf8)) == nil)
    #expect(try DockerJSON.startedAt(Data(contentsOf: Fixtures.url("docker/inspect-postgres.json"))) != nil)
  }

  @Test func parsesContentLengthAndChunked() throws {
    let body = Data("hello π".utf8)
    let length = Data("HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n".utf8) + body
    let chunked = Data("HTTP/1.1 200 OK\r\ntRaNsFeR-EnCoDiNg: chunked\r\n\r\n4;ext=yes\r\nhell\r\n4\r\no π\r\n0\r\nX-Trailer: yes\r\n\r\n".utf8)
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
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n"
  ])
  func rejectsMalformedHTTP(wire: String) {
    #expect(throws: (any Error).self) { try HTTPResponse.parse(Data(wire.utf8)) }
  }
}
