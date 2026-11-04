import AppKit
import Darwin
import Foundation

private let probes: [String: @Sendable (URL) async throws -> Void] = [
    "libproc": LibprocProbe.run,
    "docker": DockerProbe.run,
    "docker-stop": DockerProbe.stop,
]

private func runProbe() async -> Never {
    guard CommandLine.arguments.count == 3,
          CommandLine.arguments[1].hasPrefix("--probe-")
    else {
        FileHandle.standardError.write(Data("usage: ProbeApp --probe-<name> <output-path>\n".utf8))
        exit(1)
    }

    let name = String(CommandLine.arguments[1].dropFirst("--probe-".count))
    guard let probe = probes[name] else {
        FileHandle.standardError.write(Data("unknown probe: \(name)\n".utf8))
        exit(1)
    }

    do {
        try await probe(URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("probe \(name) failed: \(error)\n".utf8))
        exit(1)
    }
}

if CommandLine.arguments.count > 1 {
    Task {
        await runProbe()
    }
    dispatchMain()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
