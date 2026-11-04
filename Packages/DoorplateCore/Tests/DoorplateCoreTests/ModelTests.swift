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
