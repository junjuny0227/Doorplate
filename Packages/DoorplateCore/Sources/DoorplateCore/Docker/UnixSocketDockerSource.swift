import Darwin
import Dispatch
import Foundation
import os

public struct UnixSocketDockerSource: DockerSource {
  private let candidatePaths: [String]
  private let timeout: Duration
  private let stopTimeout: Duration
  private static let logger = Logger(
    subsystem: "io.github.junjuny0227.doorplate", category: "docker")

  public static func defaultPaths(home: String) -> [String] {
    [
      "\(home)/.docker/run/docker.sock", "/var/run/docker.sock",
      "\(home)/.orbstack/run/docker.sock", "\(home)/.colima/default/docker.sock",
    ]
  }

  public init(
    candidatePaths: [String], timeout: Duration = .seconds(1), stopTimeout: Duration = .seconds(15)
  ) {
    self.candidatePaths = candidatePaths
    self.timeout = timeout
    self.stopTimeout = stopTimeout
  }

  public func containers() async throws(DockerError) -> [Container] {
    let (path, response) = try await perform(
      paths: candidatePaths, method: "GET", target: "/containers/json", timeout: timeout)
    guard (200..<300).contains(response.status) else { throw Self.apiError(response) }
    let containers: [Container]
    do { containers = try DockerJSON.containers(response.body) } catch { throw .notResponding }
    return await withTaskGroup(of: (Int, Container).self) { group in
      for (index, container) in containers.enumerated() {
        group.addTask {
          var result = container
          if let (_, inspected) = try? await perform(
            paths: [path], method: "GET",
            target: "/containers/\(Self.pathComponent(container.id))/json", timeout: timeout),
            (200..<300).contains(inspected.status)
          {
            result.startedAt = try? DockerJSON.startedAt(inspected.body)
          }
          return (index, result)
        }
      }
      var result = containers
      for await (index, container) in group { result[index] = container }
      return result
    }
  }

  public func stop(_ id: String) async throws(DockerError) {
    let (_, response) = try await perform(
      paths: candidatePaths, method: "POST",
      target: "/containers/\(Self.pathComponent(id))/stop?t=10", timeout: stopTimeout)
    guard response.status == 204 || response.status == 304 else { throw Self.apiError(response) }
  }

  private static func pathComponent(_ value: String) -> String {
    value.addingPercentEncoding(
      withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~")))
      ?? ""
  }

  private typealias Response = (status: Int, body: Data)

  private static func apiError(_ response: Response) -> DockerError {
    struct Message: Decodable { var message: String }
    let message =
      (try? JSONDecoder().decode(Message.self, from: response.body).message)
      ?? String(decoding: response.body, as: UTF8.self)
    return .api(status: response.status, message: message)
  }

  /// Blocking POSIX work runs on Dispatch workers, not Swift's cooperative executor.
  private func perform(paths: [String], method: String, target: String, timeout: Duration)
    async throws(DockerError) -> (String, Response)
  {
    let result: Result<(String, Response), DockerError> = await withCheckedContinuation {
      continuation in
      DispatchQueue.global(qos: .utility).async {
        do {
          let deadline = ContinuousClock.now.advanced(by: timeout)
          for path in paths {
            let fd: Int32
            do { fd = try SocketIO.connect(path, until: deadline) } catch SocketIO.Failure.system(
              let code) where code == ENOENT || code == ECONNREFUSED
            { continue } catch { throw DockerError.notResponding }
            defer { Darwin.close(fd) }
            let response = try SocketIO.request(fd, method: method, target: target, until: deadline)
            continuation.resume(returning: .success((path, response)))
            return
          }
          throw DockerError.absent
        } catch let error as DockerError {
          continuation.resume(returning: .failure(error))
        } catch {
          Self.logger.debug("Docker request did not complete")
          continuation.resume(returning: .failure(.notResponding))
        }
      }
    }
    return try result.get()
  }
}

private enum SocketIO {
  enum Failure: Error {
    case system(Int32)
    case timeout
  }

  static func wait(_ fd: Int32, _ events: Int16, until deadline: ContinuousClock.Instant) throws {
    while true {
      let remaining = ContinuousClock.now.duration(to: deadline)
      guard remaining > .zero else { throw Failure.timeout }
      let parts = remaining.components
      let milliseconds =
        parts.seconds >= Int64(Int32.max) / 1000
        ? Int32.max
        : Int32(
          min(
            Int64(Int32.max),
            parts.seconds * 1000 + (parts.attoseconds + 999_999_999_999_999) / 1_000_000_000_000_000
          ))
      var descriptor = pollfd(fd: fd, events: events, revents: 0)
      let result = poll(&descriptor, 1, milliseconds)
      if result > 0 { return }
      if result == 0 { throw Failure.timeout }
      if errno != EINTR { throw Failure.system(errno) }
    }
  }

  static func connect(_ path: String, until deadline: ContinuousClock.Instant) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw Failure.system(errno) }
    do {
      guard fcntl(fd, F_SETFL, O_NONBLOCK) != -1 else { throw Failure.system(errno) }
      _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
      var noSignal: Int32 = 1
      guard
        setsockopt(
          fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
          == 0
      else {
        throw Failure.system(errno)
      }
      var address = sockaddr_un()
      address.sun_family = sa_family_t(AF_UNIX)
      address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
      let bytes = Array(path.utf8) + [0]
      guard !path.utf8.contains(0), bytes.count <= MemoryLayout.size(ofValue: address.sun_path)
      else {
        throw Failure.system(ENAMETOOLONG)
      }
      withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
      }
      if result != 0 {
        guard errno == EINPROGRESS || errno == EAGAIN || errno == EINTR else {
          throw Failure.system(errno)
        }
        try wait(fd, Int16(POLLOUT), until: deadline)
        var error: Int32 = 0
        var length = socklen_t(MemoryLayout.size(ofValue: error))
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 else {
          throw Failure.system(errno)
        }
        guard error == 0 else { throw Failure.system(error) }
      }
      return fd
    } catch {
      Darwin.close(fd)
      throw error
    }
  }

  static func request(
    _ fd: Int32, method: String, target: String, until deadline: ContinuousClock.Instant
  ) throws -> (status: Int, body: Data) {
    let request = Data(
      "\(method) \(target) HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\(method == "POST" ? "Content-Length: 0\r\n" : "")\r\n"
        .utf8)
    var offset = 0
    while offset < request.count {
      try wait(fd, Int16(POLLOUT), until: deadline)
      let count = request.withUnsafeBytes {
        Darwin.write(fd, $0.baseAddress!.advanced(by: offset), request.count - offset)
      }
      if count > 0 {
        offset += count
      } else if count < 0 && (errno == EAGAIN || errno == EINTR) {
        continue
      } else {
        throw Failure.system(count == 0 ? EPIPE : errno)
      }
    }
    var wire = Data()
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      try wait(fd, Int16(POLLIN), until: deadline)
      let count = Darwin.read(fd, &buffer, buffer.count)
      if count == 0 { break }
      if count < 0 {
        if errno == EAGAIN || errno == EINTR { continue }
        throw Failure.system(errno)
      }
      wire.append(contentsOf: buffer.prefix(count))
    }
    return try HTTPResponse.parse(wire)
  }
}
