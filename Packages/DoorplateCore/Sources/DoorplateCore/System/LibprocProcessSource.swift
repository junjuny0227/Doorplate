import Darwin
import Foundation

// sys/proc_info.h: this expression macro is not imported into Swift.
// swift-format-ignore: AlwaysUseLowerCamelCase
private let PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN

public struct LibprocProcessSource: ProcessSource {
  public init() {}

  public func listeners() throws -> [Listener] {
    var result: [Listener] = []
    for pid in try processIDs() {
      result.append(contentsOf: bindings(pid: pid))
    }
    return result.sorted {
      if $0.port != $1.port { return $0.port < $1.port }
      if $0.pid != $1.pid { return $0.pid < $1.pid }
      return $0.address < $1.address
    }
  }

  public func process(_ pid: Int32) -> ProcessRecord? {
    guard pid > 0 else { return nil }
    var bsd = proc_bsdinfo()
    let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, bsdSize) == bsdSize else { return nil }
    var name = cString(bsd.pbi_name)
    if name.isEmpty { name = cString(bsd.pbi_comm) }
    var result = ProcessRecord(
      pid: pid, name: name, parentPID: Int32(bsd.pbi_ppid),
      startedAt: Date(
        timeIntervalSince1970: Double(bsd.pbi_start_tvsec) + Double(bsd.pbi_start_tvusec)
          / 1_000_000),
      uid: bsd.pbi_uid)
    var path = [UInt8](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
    let pathSize = UInt32(path.count)
    if proc_pidpath(pid, &path, pathSize) > 0 {
      result.executablePath = String(decoding: path.prefix { $0 != 0 }, as: UTF8.self)
    } else if unavailable(errno) {
      return nil
    }
    var vnode = proc_vnodepathinfo()
    let vnodeSize = Int32(MemoryLayout<proc_vnodepathinfo>.size)
    if proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnode, vnodeSize) == vnodeSize {
      result.cwd = cString(vnode.pvi_cdir.vip_path)
    } else if unavailable(errno) {
      return nil
    }
    if let limit = argumentLimit() {
      var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
      var bytes = [UInt8](repeating: 0, count: limit)
      var size = bytes.count
      let status = bytes.withUnsafeMutableBytes { sysctl(&mib, 3, $0.baseAddress, &size, nil, 0) }
      if status == 0, size <= bytes.count {
        result.arguments = ProcessArguments.parse(Array(bytes.prefix(size)))?.arguments
      } else if status != 0 && unavailable(errno) {
        return nil
      }
    }
    return result
  }

  private func unavailable(_ code: Int32) -> Bool {
    code == EPERM || code == EACCES || code == ESRCH
  }

  private func cString<T>(_ value: T) -> String {
    withUnsafeBytes(of: value) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
  }

  private func argumentLimit() -> Int? {
    var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
    var limit: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctl(&mib, 2, &limit, &size, nil, 0) == 0, limit > 0 else { return nil }
    return Int(limit)
  }

  private func processIDs() throws -> [Int32] {
    // Query sizes afresh each scan and retry when the process table grows.
    for _ in 0..<4 {
      errno = 0
      let count = proc_listallpids(nil, 0)
      guard count > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
      var pids = [Int32](repeating: 0, count: Int(count) + 256)
      let capacity = Int32(pids.count * MemoryLayout<Int32>.stride)
      let read = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, capacity) }
      guard read > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
      if read < pids.count { return pids.prefix(Int(read)).filter { $0 > 0 }.sorted() }
    }
    throw POSIXError(.EAGAIN)
  }

  private func bindings(pid: Int32) -> [Listener] {
    for _ in 0..<4 {
      let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
      guard needed > 0 else { return [] }
      let stride = MemoryLayout<proc_fdinfo>.stride
      var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 32)
      let capacity = Int32(fds.count * stride)
      let read = fds.withUnsafeMutableBytes {
        proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, capacity)
      }
      guard read >= 0 else { return [] }
      if read == capacity { continue }
      var result: [Listener] = []
      var seen = Set<UInt64>()
      for fd in fds.prefix(Int(read) / stride) where fd.proc_fdtype == PROX_FDTYPE_SOCKET {
        var info = socket_fdinfo()
        let size = Int32(MemoryLayout<socket_fdinfo>.size)
        guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, size) == size else {
          if unavailable(errno) { return [] }
          continue
        }
        guard info.psi.soi_kind == SOCKINFO_TCP else { continue }
        let tcp = info.psi.soi_proto.pri_tcp
        guard tcp.tcpsi_state == TSI_S_LISTEN else { continue }
        var local = tcp.tcpsi_ini.insi_laddr
        let flags = tcp.tcpsi_ini.insi_vflag
        var text = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let converted: Bool
        // Dual-stack wildcard sockets carry both bits: IPv6 must win.
        if flags & UInt8(INI_IPV6) != 0 {
          converted = inet_ntop(AF_INET6, &local.ina_6, &text, socklen_t(text.count)) != nil
        } else if flags & UInt8(INI_IPV4) != 0 {
          converted =
            inet_ntop(AF_INET, &local.ina_46.i46a_addr4, &text, socklen_t(text.count)) != nil
        } else {
          continue
        }
        guard converted, seen.insert(info.psi.soi_so).inserted else { continue }
        result.append(
          Listener(
            pid: pid, port: UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)),
            address: String(
              decoding: text.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self),
            socketID: info.psi.soi_so))
      }
      return result
    }
    return []
  }
}
