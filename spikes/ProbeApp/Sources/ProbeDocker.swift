import Darwin
import Foundation
import os

// One monotonic deadline covers connect, partial writes, and all response reads.
private enum SocketFailure: Error {
    case system(Int32)
    case timeout
    case invalidHTTP

    var kind: String {
        switch self {
        case .system(ENOENT): return "ENOENT"
        case .system(ECONNREFUSED): return "ECONNREFUSED"
        case .system(let code): return String(code)
        case .timeout: return "timeout"
        case .invalidHTTP: return "invalidHTTP"
        }
    }
}

private struct DockerHTTP {
    let status: Int
    let chunked: Bool
    let body: Data
    let wire: Data

    static func wait(_ fd: Int32, _ events: Int16, until deadline: UInt64) throws {
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { throw SocketFailure.timeout }
            let remaining = Int32(min((deadline - now + 999_999) / 1_000_000, UInt64(Int32.max)))
            var descriptor = pollfd(fd: fd, events: events, revents: 0)
            let result = poll(&descriptor, 1, remaining)
            if result > 0 { return } // SO_ERROR/read/write supplies the precise errno.
            if result == 0 { throw SocketFailure.timeout }
            if errno != EINTR { throw SocketFailure.system(errno) }
        }
    }

    static func connectSocket(_ path: String, until deadline: UInt64) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketFailure.system(errno) }
        do {
            guard fcntl(fd, F_SETFL, O_NONBLOCK) != -1 else { throw SocketFailure.system(errno) }
            var noSignal: Int32 = 1
            guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal))) == 0
            else { throw SocketFailure.system(errno) }
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8) + [0]
            guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
                throw SocketFailure.system(ENAMETOOLONG)
            }
            withUnsafeMutableBytes(of: &address.sun_path) { destination in
                destination.copyBytes(from: bytes)
            }
            address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result != 0 {
                guard errno == EINPROGRESS || errno == EAGAIN || errno == EINTR else {
                    throw SocketFailure.system(errno)
                }
                try wait(fd, Int16(POLLOUT), until: deadline)
                var error: Int32 = 0
                var length = socklen_t(MemoryLayout.size(ofValue: error))
                guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 else {
                    throw SocketFailure.system(errno)
                }
                guard error == 0 else { throw SocketFailure.system(error) }
            }
            return fd
        } catch {
            Darwin.close(fd)
            throw error
        }
    }

    static func request(_ fd: Int32, method: String = "GET", target: String, until deadline: UInt64) throws -> DockerHTTP {
        let request = Data("\(method) \(target) HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\(method == "POST" ? "Content-Length: 0\r\n" : "")\r\n".utf8)
        var offset = 0
        while offset < request.count {
            try wait(fd, Int16(POLLOUT), until: deadline)
            let count = request.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: offset), request.count - offset) }
            if count > 0 { offset += count }
            else if count < 0 && (errno == EAGAIN || errno == EINTR) { continue }
            else { throw SocketFailure.system(count == 0 ? EPIPE : errno) }
        }
        var wire = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            try wait(fd, Int16(POLLIN), until: deadline)
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EAGAIN || errno == EINTR { continue }
                throw SocketFailure.system(errno)
            }
            wire.append(contentsOf: buffer.prefix(count))
        }
        let separator = Data("\r\n\r\n".utf8)
        guard let range = wire.range(of: separator),
              let header = String(data: wire[..<range.lowerBound], encoding: .utf8),
              let statusToken = header.components(separatedBy: "\r\n").first?.split(separator: " ").dropFirst().first,
              let status = Int(statusToken)
        else { throw SocketFailure.invalidHTTP }
        let lines = header.components(separatedBy: "\r\n").dropFirst()
        let chunked = lines.contains { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            return parts.count == 2 && parts[0].lowercased() == "transfer-encoding"
                && parts[1].split(separator: ",").contains { $0.trimmingCharacters(in: .whitespaces).lowercased() == "chunked" }
        }
        let encoded = Data(wire[range.upperBound...])
        let body = try chunked ? decodeChunks(encoded) : encoded
        if let lengthLine = lines.first(where: { $0.lowercased().hasPrefix("content-length:") }),
           let length = Int(lengthLine.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)),
           !chunked && length != body.count { throw SocketFailure.invalidHTTP }
        return DockerHTTP(status: status, chunked: chunked, body: body, wire: wire)
    }

    private static func decodeChunks(_ data: Data) throws -> Data {
        var offset = data.startIndex
        var result = Data()
        let crlf = Data("\r\n".utf8)
        while offset < data.endIndex {
            guard let line = data.range(of: crlf, in: offset..<data.endIndex),
                  let text = String(data: data[offset..<line.lowerBound], encoding: .utf8),
                  let size = Int(text.split(separator: ";", maxSplits: 1)[0].trimmingCharacters(in: .whitespaces), radix: 16)
            else { throw SocketFailure.invalidHTTP }
            offset = line.upperBound
            if size == 0 {
                guard data.range(of: crlf, in: offset..<data.endIndex) != nil else { throw SocketFailure.invalidHTTP }
                return result
            }
            guard size <= data.endIndex - offset - 2 else { throw SocketFailure.invalidHTTP }
            result.append(data[offset..<(offset + size)])
            offset += size
            guard data[offset..<(offset + 2)] == crlf else { throw SocketFailure.invalidHTTP }
            offset += 2
        }
        throw SocketFailure.invalidHTTP
    }
}

enum DockerProbe {
    private static let logger = Logger(subsystem: "io.github.junjuny0227.doorplate.probe", category: "docker")

    private static var candidates: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.docker/run/docker.sock", "/var/run/docker.sock", "\(home)/.orbstack/run/docker.sock", "\(home)/.colima/default/docker.sock"]
    }

    static func run(_ outputURL: URL) async throws {
        try measure(outputURL, stopping: false)
    }

    static func stop(_ outputURL: URL) async throws {
        try measure(outputURL, stopping: true)
    }

    private static func measure(_ outputURL: URL, stopping: Bool) throws {
        let directory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var attempts: [[String: Any]] = []
        var selected: String?
        var list: DockerHTTP?
        for path in candidates {
            let started = DispatchTime.now().uptimeNanoseconds
            let deadline = started + 1_000_000_000
            var info = stat()
            var record: [String: Any] = ["path": path, "exists": lstat(path, &info) == 0, "status": NSNull()]
            do {
                let fd = try DockerHTTP.connectSocket(path, until: deadline)
                defer { Darwin.close(fd) }
                record["connect"] = "ok"
                if selected == nil {
                    selected = path // Only the first connected candidate receives the list request.
                    do {
                        let response = try DockerHTTP.request(fd, target: "/containers/json", until: deadline)
                        list = response
                        record["status"] = response.status
                        record["chunked"] = response.chunked
                    } catch {
                        record["error"] = errorKind(error)
                    }
                }
            } catch {
                record["connect"] = errorKind(error)
                if case SocketFailure.system(let code) = error { record["errno"] = code }
            }
            record["ms"] = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            attempts.append(record)
        }
        var result: [String: Any] = ["paths": attempts, "selectedPath": selected as Any? ?? NSNull(), "chunked": list?.chunked as Any? ?? NSNull()]
        if let list, let selected {
            try save(list, named: "docker-list", in: directory)
            result["status"] = list.status
            if list.status == 200 {
                guard let containers = try JSONSerialization.jsonObject(with: list.body) as? [[String: Any]] else {
                    throw SocketFailure.invalidHTTP
                }
                var inspected: [[String: Any]] = []
                for container in containers {
                    guard let id = container["Id"] as? String else { continue }
                    let labels = container["Labels"] as? [String: String] ?? [:]
                    let service = labels["com.docker.compose.service"] ?? id
                    // Preserve a stable service fixture name without allowing label path traversal.
                    let safeService = service.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || "-_".unicodeScalars.contains($0) ? String($0) : "_" }.joined()
                    do {
                        let response = try fetch(selected, target: "/containers/\(id)/json")
                        try save(response, named: "docker-inspect-\(safeService)", in: directory)
                        inspected.append(["id": id, "service": service, "status": response.status, "chunked": response.chunked])
                    } catch {
                        inspected.append(["id": id, "service": service, "error": errorKind(error)])
                    }
                }
                result["inspects"] = inspected
                if stopping {
                    if let redis = containers.first(where: { container in
                        let labels = container["Labels"] as? [String: String] ?? [:]
                        return labels["com.docker.compose.project"] == "doorplate-spike" && labels["com.docker.compose.service"] == "redis"
                    }), let id = redis["Id"] as? String {
                        let started = DispatchTime.now().uptimeNanoseconds
                        do {
                            let response = try fetch(selected, method: "POST", target: "/containers/\(id)/stop?t=10", timeout: 15)
                            try save(response, named: "docker-stop-response", in: directory)
                            result["stop"] = ["id": id, "status": response.status, "chunked": response.chunked,
                                              "seconds": Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000]
                        } catch {
                            result["stop"] = ["id": id, "error": errorKind(error), "seconds": Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000]
                        }
                    } else { result["stop"] = ["error": "redisNotFound"] }
                }
            }
        }
        logger.info("Docker probe finished; connected: \(selected != nil)")
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: outputURL, options: .atomic)
    }

    private static func fetch(_ path: String, method: String = "GET", target: String, timeout: UInt64 = 1) throws -> DockerHTTP {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeout * 1_000_000_000
        let fd = try DockerHTTP.connectSocket(path, until: deadline)
        defer { Darwin.close(fd) }
        return try DockerHTTP.request(fd, method: method, target: target, until: deadline)
    }

    private static func save(_ response: DockerHTTP, named name: String, in directory: URL) throws {
        try response.body.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
        try response.wire.write(to: directory.appendingPathComponent("\(name).http"), options: .atomic)
    }

    private static func errorKind(_ error: Error) -> String {
        (error as? SocketFailure)?.kind ?? String(describing: error)
    }
}
