import Darwin
import Foundation

public struct LocalFileProbe: FileProbe {
  public init() {}

  public var homeDirectory: String { NSHomeDirectory() }

  public func presence(_ path: String) -> FilePresence {
    var info = stat()
    if stat(path, &info) == 0 { return .present }
    switch errno {
    case ENOENT, ENOTDIR: return .absent
    case EPERM, EACCES: return .denied
    default: return .absent
    }
  }

  public func read(_ path: String) -> String? {
    // O_NONBLOCK and the regular-file check avoid blocking on FIFOs/devices.
    let fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
    var data = Data()
    var bytes = [UInt8](repeating: 0, count: 16_384)
    while true {
      let count = bytes.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
      if count < 0 {
        if errno == EINTR { continue }
        return nil
      }
      if count == 0 { return String(data: data, encoding: .utf8) }
      data.append(contentsOf: bytes.prefix(count))
    }
  }
}
