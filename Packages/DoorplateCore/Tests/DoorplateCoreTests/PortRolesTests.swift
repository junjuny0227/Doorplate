import Testing

@testable import DoorplateCore

struct PortRolesTests {
  private func listener(_ port: UInt16, address: String = "127.0.0.1") -> Listener {
    Listener(pid: 1, port: port, address: address)
  }

  @Test(arguments: ["*:5005", "5005", "127.0.0.1:5005"])
  func jdwpAddressForms(address: String) {
    let result = PortRoleDetector.assign(
      [listener(5005)],
      arguments: ["-agentlib:jdwp=transport=dt_socket,server=y,address=\(address)"]
    )
    #expect(result.primary == PortBinding(port: 5005, exposure: .loopback, role: .debugger))
  }

  @Test func jdwpXrunForm() {
    let result = PortRoleDetector.assign(
      [listener(5005)], arguments: ["-Xrunjdwp:transport=dt_socket,server=y,address=5005"]
    )
    #expect(result.primary.role == .debugger)
  }

  @Test(arguments: [
    ("--inspect", UInt16(9229)), ("--inspect=9230", 9230), ("--inspect-brk=127.0.0.1:9231", 9231),
  ])
  func nodeInspectForms(argument: String, port: UInt16) {
    let result = PortRoleDetector.assign([listener(port)], arguments: [argument])
    #expect(result.primary.role == .inspector)
  }

  @Test func springWithDebuggerAndLiveReload() {
    let result = PortRoleDetector.assign(
      [listener(35729), listener(8080), listener(5005)],
      arguments: ["-agentlib:jdwp=address=5005"]
    )
    #expect(result.primary == PortBinding(port: 8080, exposure: .loopback, role: nil))
    #expect(
      result.extras == [
        PortBinding(port: 5005, exposure: .loopback, role: .debugger),
        PortBinding(port: 35729, exposure: .loopback, role: .liveReload),
      ])
  }

  @Test func onlyAuxiliaryPorts() {
    let result = PortRoleDetector.assign([listener(9229)], arguments: ["--inspect"])
    #expect(result.primary.role == .inspector)
    #expect(result.extras.isEmpty)
  }

  @Test func exposureMerge() {
    let result = PortRoleDetector.assign(
      [
        listener(8080, address: "127.0.0.1"), listener(8080, address: "::"),
        listener(5173, address: "::1"), listener(5173, address: "127.0.0.1"),
      ],
      arguments: []
    )
    #expect(result.primary == PortBinding(port: 5173, exposure: .loopback, role: nil))
    #expect(result.extras == [PortBinding(port: 8080, exposure: .network, role: nil)])
  }

  @Test(arguments: [
    (UInt16(5432), Optional<String>.none, false),
    (8080, nil, true),
    (55432, Optional("postgres:16-alpine"), false),
    (55432, Optional("bitnami/postgresql:16"), false),
    (9121, Optional("oliver006/redis_exporter"), true),
    (9121, Optional("ghcr.io/acme/redis-exporter:1"), true),
    (8080, Optional("library/nginx"), true),
  ])
  func likelyHTTPRules(port: UInt16, image: String?, expected: Bool) {
    #expect(HTTPGuess.likelyHTTP(port: port, image: image) == expected)
  }
}
