import Foundation

enum DockerProbe {
    static func run(_ outputURL: URL) async throws {
        throw ProbeError.notImplemented
    }

    static func stop(_ outputURL: URL) async throws {
        throw ProbeError.notImplemented
    }
}
