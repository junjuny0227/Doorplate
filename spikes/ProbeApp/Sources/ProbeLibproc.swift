import Darwin
import Dispatch
import Foundation
import os

enum ProbeError: Error, CustomStringConvertible {
    case notImplemented

    var description: String { "probe not implemented yet" }
}

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
                    address: String(cString: text),
                    socketID: String(format: "0x%016llx", info.psi.soi_so)
                ))
            }
            return result
        }
        errors.record(EAGAIN)
        return []
    }

    static func run(_ outputURL: URL) async throws {
        throw ProbeError.notImplemented
    }
}
