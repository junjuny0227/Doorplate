import Darwin
import Dispatch
import Foundation
import os

enum ProbeError: Error, CustomStringConvertible {
    case notImplemented

    var description: String { "probe not implemented yet" }
}

// sys/proc_info.h: this expression macro is not imported into Swift.
private let PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN

enum LibprocProbe {
    struct ErrorCounts: Codable, Sendable {
        var EPERM = 0
        var ESRCH = 0
        var other = 0

        mutating func record(_ code: Int32 = errno) {
            switch code {
            case Darwin.EPERM, EACCES: EPERM += 1
            case Darwin.ESRCH: ESRCH += 1
            default: other += 1
            }
        }
    }

    struct Binding: Sendable {
        var pid: Int32
        var port: UInt16
        var address: String
        var socketID: String
    }

    // Buffer sizes are queried again on every scan; retry if the table grows.
    static func processIDs(errors: inout ErrorCounts) throws -> [Int32] {
        for _ in 0..<4 {
            errno = 0
            let count = proc_listallpids(nil, 0)
            guard count > 0 else {
                let code = errno
                errors.record(code)
                throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
            }
            var pids = [Int32](repeating: 0, count: Int(count) + 256)
            let bytes = Int32(pids.count * MemoryLayout<Int32>.stride)
            let read = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, bytes) }
            guard read > 0 else {
                let code = errno
                errors.record(code)
                throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
            }
            if read < pids.count { return pids.prefix(Int(read)).filter { $0 > 0 }.sorted() }
        }
        throw POSIXError(.EAGAIN)
    }

    static func bindings(pid: Int32, errors: inout ErrorCounts) -> [Binding] {
        for _ in 0..<4 {
            errno = 0
            let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
            guard needed > 0 else {
                if needed < 0 || errno != 0 { errors.record() }
                return []
            }
            let stride = MemoryLayout<proc_fdinfo>.stride
            var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 32)
            let capacity = Int32(fds.count * stride)
            let read = fds.withUnsafeMutableBytes {
                proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, capacity)
            }
            guard read >= 0 else { errors.record(); return [] }
            if read == capacity { continue }
            var result: [Binding] = []
            for fd in fds.prefix(Int(read) / stride) where fd.proc_fdtype == PROX_FDTYPE_SOCKET {
                var info = socket_fdinfo()
                let size = Int32(MemoryLayout<socket_fdinfo>.size)
                let received = proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, size)
                guard received == size else { errors.record(); continue }
                guard info.psi.soi_kind == SOCKINFO_TCP else { continue }
                let tcp = info.psi.soi_proto.pri_tcp
                guard tcp.tcpsi_state == TSI_S_LISTEN else { continue }
                var local = tcp.tcpsi_ini.insi_laddr
                let flags = tcp.tcpsi_ini.insi_vflag
                var text = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                // Dual-stack wildcard sockets carry both bits: IPv6 must win.
                let converted: Bool
                if flags & UInt8(INI_IPV6) != 0 {
                    converted = inet_ntop(AF_INET6, &local.ina_6, &text, socklen_t(text.count)) != nil
                } else if flags & UInt8(INI_IPV4) != 0 {
                    converted = inet_ntop(AF_INET, &local.ina_46.i46a_addr4, &text, socklen_t(text.count)) != nil
                } else { continue }
                guard converted else { errors.record(); continue }
                result.append(Binding(
                    pid: pid,
                    port: UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)),
                    address: String(decoding: text.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self),
                    socketID: String(format: "0x%016llx", info.psi.soi_so)
                ))
            }
            return result
        }
        errors.record(EAGAIN)
        return []
    }

    struct ShortArgv: Codable, Sendable {
        var pid: Int32
        var name: String
        var argc: Int
        var read: Int
    }

    struct Details: Sendable {
        var name = ""
        var path = ""
        var cwd = ""
        var argv: [String] = []
        var ppid: UInt32 = 0
        var uid: UInt32 = 0
        var startedAt = ""
        var argc = 0
        var argvBytes = 0
        var argvRead = false
    }

    static func cString<T>(_ value: T) -> String {
        withUnsafeBytes(of: value) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static func argumentLimit() throws -> Int {
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        var limit: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctl(&mib, 2, &limit, &size, nil, 0) == 0, limit > 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return Int(limit)
    }

    static func details(pid: Int32, argmax: Int, errors: inout ErrorCounts) -> Details {
        var result = Details()
        var bsd = proc_bsdinfo()
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, bsdSize) == bsdSize {
            result.name = cString(bsd.pbi_name)
            if result.name.isEmpty { result.name = cString(bsd.pbi_comm) }
            result.ppid = bsd.pbi_ppid
            result.uid = bsd.pbi_uid
            let seconds = Double(bsd.pbi_start_tvsec) + Double(bsd.pbi_start_tvusec) / 1_000_000
            result.startedAt = Date(timeIntervalSince1970: seconds).formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        } else { errors.record() }
        var path = [UInt8](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let pathSize = UInt32(path.count)
        if proc_pidpath(pid, &path, pathSize) > 0 {
            result.path = String(decoding: path.prefix { $0 != 0 }, as: UTF8.self)
        } else { errors.record() }
        var vnode = proc_vnodepathinfo()
        let vnodeSize = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        if proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnode, vnodeSize) == vnodeSize {
            result.cwd = cString(vnode.pvi_cdir.vip_path)
        } else { errors.record() }
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var bytes = [UInt8](repeating: 0, count: argmax)
        var size = bytes.count
        let status = bytes.withUnsafeMutableBytes { sysctl(&mib, 3, $0.baseAddress, &size, nil, 0) }
        guard status == 0 else { errors.record(); return result }
        guard size >= MemoryLayout<Int32>.size else { errors.record(EIO); return result }
        result.argc = Int(bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        guard result.argc >= 0 else { errors.record(EIO); return result }
        result.argvRead = true
        var cursor = MemoryLayout<Int32>.size
        // Skip executable path and alignment NULs, never decode the environment.
        while cursor < size && bytes[cursor] != 0 { cursor += 1 }
        while cursor < size && bytes[cursor] == 0 { cursor += 1 }
        // A NUL-filled tail after a rewritten process title ends visible argv.
        while cursor < size && bytes[cursor] != 0 && result.argv.count < result.argc {
            let start = cursor
            while cursor < size && bytes[cursor] != 0 { cursor += 1 }
            guard cursor < size else { break } // unterminated tail is not an argument
            result.argv.append(String(decoding: bytes[start..<cursor], as: UTF8.self))
            result.argvBytes += cursor - start + 1
            cursor += 1
        }
        return result
    }

    // A detached Dispatch read may remain blocked in TCC. Do not await it via a
    // task group: structured cancellation would still wait for the blocking I/O.
    final class PackageReads: @unchecked Sendable {
        private let lock = NSLock()
        private var results: [String: String] = [:]
        private let group = DispatchGroup()

        func start(_ directories: Set<String>) {
            for directory in directories where !directory.isEmpty {
                group.enter()
                DispatchQueue.global(qos: .utility).async { [self] in
                    let path = URL(fileURLWithPath: directory).appendingPathComponent("package.json").path
                    let fd = Darwin.open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
                    let result: String
                    if fd < 0 {
                        result = errno == ENOENT || errno == ENOTDIR ? "absent" : "denied"
                    } else {
                        defer { Darwin.close(fd) }
                        var info = stat()
                        var byte: UInt8 = 0
                        // Avoid blocking on special files; a real read exercises TCC.
                        if fstat(fd, &info) == 0 && (info.st_mode & S_IFMT) == S_IFREG {
                            result = Darwin.read(fd, &byte, 1) >= 0 ? "read" : "denied"
                        } else { result = "denied" }
                    }
                    lock.lock()
                    results[directory] = result
                    lock.unlock()
                    group.leave()
                }
            }
        }

        func finish() -> [String: String] {
            _ = group.wait(timeout: .now() + .seconds(3))
            lock.lock()
            defer { lock.unlock() }
            return results
        }
    }

    struct Listener: Codable, Sendable {
        var pid: Int32
        var port: UInt16
        var address: String
        var socketID: String
        var name: String
        var path: String
        var cwd: String
        var argv: [String]
        var ppid: UInt32
        var uid: UInt32
        var startedAt: String
        var packageJSON = "pending"
    }

    struct SharedSocket: Codable, Sendable {
        var socketID: String
        var pids: [Int32]
    }

    struct Scan: Sendable {
        var processCount: Int
        var errors: ErrorCounts
        var longestArgvBytes: Int
        var argvShorterThanArgc: [ShortArgv]
        var listeners: [Listener]
    }

    struct Report: Codable, Sendable {
        var processCount: Int
        var runs: Int
        var medianMs: Double
        var p95Ms: Double
        var errors: ErrorCounts
        var missingSymbols = ["PROC_PIDPATHINFO_MAXSIZE"]
        var longestArgvBytes: Int
        var argvShorterThanArgc: [ShortArgv]
        var sharedSockets: [SharedSocket]
        var listeners: [Listener]
    }

    static func scan(argmax: Int) throws -> Scan {
        var errors = ErrorCounts()
        let pids = try processIDs(errors: &errors)
        var result = Scan(processCount: pids.count, errors: errors, longestArgvBytes: 0,
                          argvShorterThanArgc: [], listeners: [])
        for pid in pids {
            let sockets = bindings(pid: pid, errors: &result.errors)
            let info = details(pid: pid, argmax: argmax, errors: &result.errors)
            result.longestArgvBytes = max(result.longestArgvBytes, info.argvBytes)
            if info.argvRead && info.argv.count < info.argc {
                result.argvShorterThanArgc.append(ShortArgv(pid: pid, name: info.name,
                                                          argc: info.argc, read: info.argv.count))
            }
            // A duplicated descriptor in one process is not a second listener.
            var seen = Set<String>()
            for socket in sockets where seen.insert(socket.socketID).inserted {
                result.listeners.append(Listener(pid: pid, port: socket.port, address: socket.address,
                    socketID: socket.socketID, name: info.name, path: info.path, cwd: info.cwd,
                    argv: info.argv, ppid: info.ppid, uid: info.uid, startedAt: info.startedAt))
            }
        }
        result.listeners.sort {
            if $0.port != $1.port { return $0.port < $1.port }
            if $0.pid != $1.pid { return $0.pid < $1.pid }
            return $0.address < $1.address
        }
        return result
    }

    static func run(_ outputURL: URL) async throws {
        // Measure full libproc/sysctl collection, not filesystem/TCC user latency.
        let report = try await Task.detached(priority: .userInitiated) {
            let argmax = try argumentLimit()
            var times: [Double] = []
            var last: Scan?
            for _ in 0..<20 {
                let start = DispatchTime.now().uptimeNanoseconds
                last = try scan(argmax: argmax)
                times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            }
            guard var snapshot = last else { throw POSIXError(.EIO) }
            let packages = PackageReads()
            packages.start(Set(snapshot.listeners.map(\.cwd)))
            let reads = packages.finish()
            for index in snapshot.listeners.indices {
                let cwd = snapshot.listeners[index].cwd
                snapshot.listeners[index].packageJSON = cwd.isEmpty ? "denied" : (reads[cwd] ?? "pending")
            }
            let grouped = Dictionary(grouping: snapshot.listeners, by: \.socketID)
            let shared = grouped.compactMap { id, listeners -> SharedSocket? in
                let pids = Set(listeners.map(\.pid)).sorted()
                return pids.count > 1 ? SharedSocket(socketID: id, pids: pids) : nil
            }.sorted { $0.socketID < $1.socketID }
            let sorted = times.sorted()
            // Even-sized median; p95 uses nearest-rank ceil(0.95 * 20).
            return Report(processCount: snapshot.processCount, runs: times.count,
                medianMs: (sorted[9] + sorted[10]) / 2, p95Ms: sorted[18],
                errors: snapshot.errors, longestArgvBytes: snapshot.longestArgvBytes,
                argvShorterThanArgc: snapshot.argvShorterThanArgc,
                sharedSockets: shared, listeners: snapshot.listeners)
        }.value
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(report).write(to: outputURL, options: .atomic)
        Logger(subsystem: "io.github.junjuny0227.doorplate.probe", category: "libproc")
            .info("libproc collected \(report.processCount) processes in \(report.medianMs) ms median")
    }
}
