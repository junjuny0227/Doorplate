import Foundation

enum ProbeError: Error, CustomStringConvertible {
    case notImplemented

    var description: String {
        switch self {
        case .notImplemented:
            "probe not implemented yet"
        }
    }
}

enum LibprocProbe {
    static func run(_ outputURL: URL) async throws {
        throw ProbeError.notImplemented
    }
}
