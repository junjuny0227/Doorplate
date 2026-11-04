import Darwin
import Dispatch
import Foundation

/// Only binds owned, short paths below the configured scratch directory.
final class UnixTestServer: @unchecked Sendable {
  struct Response: Sendable {
    var status: Int = 200
    var body: Data = Data()
    var chunked = false
    var delay: TimeInterval = 0
    var fragmentSize: Int = 0

    var wire: Data {
      let head = "HTTP/1.1 \(status) Test\r\nConnection: close\r\n"
      if chunked {
        return Data(
          (head + "Transfer-Encoding: chunked\r\n\r\n\(String(body.count, radix: 16))\r\n").utf8)
          + body + Data("\r\n0\r\n\r\n".utf8)
      }
      return Data((head + "Content-Length: \(body.count)\r\n\r\n").utf8) + body
    }
  }
  enum Mode: Sendable {
    case responses(@Sendable (String) -> Response)
    case silent
    case refused
  }
  private final class State: @unchecked Sendable {
    let lock = NSLock()
    var stopped = false
    var requests: [String] = []
    func isStopped() -> Bool { lock.withLock { stopped } }
    func record(_ request: String) { lock.withLock { requests.append(request) } }
  }
  let path: String
  private let fd: Int32
  private let state = State()
  private let group = DispatchGroup()
  var requests: [String] { state.lock.withLock { state.requests } }

  static func unusedPath() -> String {
    let base =
      ProcessInfo.processInfo.environment["TMPDIR"] ?? NSHomeDirectory() + "/.hermes/cache/scratch"
    return URL(fileURLWithPath: base).appendingPathComponent(
      "dp-\(UUID().uuidString.prefix(8)).sock"
    ).path
  }

  init(_ mode: Mode) throws {
    path = Self.unusedPath()
    fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(.EIO) }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    let bytes = Array(path.utf8) + [0]
    guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
      Darwin.close(fd)
      throw POSIXError(.ENAMETOOLONG)
    }
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard bound == 0 else {
      Darwin.close(fd)
      throw POSIXError(.EIO)
    }
    if case .refused = mode {
      Darwin.close(fd)
      return
    }
    guard listen(fd, 32) == 0, fcntl(fd, F_SETFL, O_NONBLOCK) != -1 else {
      Darwin.close(fd)
      unlink(path)
      throw POSIXError(.EIO)
    }
    let fd = fd
    let state = state
    let group = group
    group.enter()
    DispatchQueue.global().async {
      defer {
        group.leave()
        Darwin.close(fd)
      }
      while !state.isStopped() {
        var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 20) > 0 else { continue }
        let client = accept(fd, nil, nil)
        guard client >= 0 else { continue }
        group.enter()
        DispatchQueue.global().async {
          defer {
            Darwin.close(client)
            group.leave()
          }
          Self.serve(client, mode: mode, state: state)
        }
      }
    }
  }

  deinit {
    state.lock.withLock { state.stopped = true }
    group.wait()
    unlink(path)
  }

  private static func serve(_ fd: Int32, mode: Mode, state: State) {
    _ = fcntl(fd, F_SETFL, O_NONBLOCK)
    var noSignal: Int32 = 1
    _ = setsockopt(
      fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
    var request = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while !state.isStopped() && request.range(of: Data("\r\n\r\n".utf8)) == nil {
      var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      guard poll(&descriptor, 1, 20) > 0 else { continue }
      let count = Darwin.read(fd, &buffer, buffer.count)
      if count == 0 { return }
      if count < 0 {
        if errno == EAGAIN || errno == EINTR { continue }
        return
      }
      request.append(contentsOf: buffer.prefix(count))
    }
    guard !state.isStopped() else { return }
    let firstLine = String(decoding: request, as: UTF8.self).components(separatedBy: "\r\n")[0]
    state.record(firstLine)
    guard case .responses(let handler) = mode else {
      while !state.isStopped() { Thread.sleep(forTimeInterval: 0.01) }
      return
    }
    let response = handler(firstLine)
    let deadline = ContinuousClock.now.advanced(by: .seconds(response.delay))
    while ContinuousClock.now < deadline && !state.isStopped() {
      Thread.sleep(forTimeInterval: 0.01)
    }
    let wire = response.wire
    var offset = 0
    while offset < wire.count && !state.isStopped() {
      let size =
        response.fragmentSize > 0
        ? min(response.fragmentSize, wire.count - offset) : wire.count - offset
      let count = wire.withUnsafeBytes {
        Darwin.write(fd, $0.baseAddress!.advanced(by: offset), size)
      }
      if count > 0 {
        offset += count
      } else if count < 0 && (errno == EAGAIN || errno == EINTR) {
        Thread.sleep(forTimeInterval: 0.001)
      } else {
        return
      }
    }
  }
}
