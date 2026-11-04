import Darwin
import Foundation
import Testing

@testable import DoorplateCore

struct SystemSourceTests {
  private func buffer(argc: Int32, tail: [UInt8]) -> [UInt8] {
    withUnsafeBytes(of: argc) { Array($0) } + tail
  }

  @Test func parsesProcArgs() throws {
    let bytes = buffer(argc: 3, tail: Array("/bin/x\0\0\0\0x\0-a\0b\0HOME=/u\0".utf8))
    let result = try #require(ProcessArguments.parse(bytes))
    #expect(result.executable == "/bin/x")
    #expect(result.arguments == ["x", "-a", "b"])
  }

  @Test func parsesHugeArgument() throws {
    let huge = String(repeating: "x", count: 200_000)
    let result = try #require(
      ProcessArguments.parse(buffer(argc: 1, tail: Array("/bin/x\0\0\(huge)\0HOME=/u\0".utf8))))
    #expect(result.arguments == [huge])
  }

  @Test func rejectsTruncatedHeader() {
    for bytes: [UInt8] in [[], [0], [0, 0, 0], buffer(argc: 1, tail: Array("/bin/x".utf8))] {
      #expect(ProcessArguments.parse(bytes) == nil)
    }
  }

  @Test func titleRewrittenProcessKeepsReadableArgs() throws {
    let result = try #require(
      ProcessArguments.parse(
        buffer(argc: 5, tail: Array("/bin/x\0\0next-server (v15.0.0)\0\0\0\0".utf8))))
    #expect(result.arguments == ["next-server (v15.0.0)"])
  }

  @Test func stopsAtEmptyOrUnterminatedArgument() throws {
    let empty = try #require(
      ProcessArguments.parse(buffer(argc: 3, tail: Array("/bin/x\0x\0\0HOME=/u\0".utf8))))
    #expect(empty.arguments == ["x"])
    let truncated = try #require(
      ProcessArguments.parse(buffer(argc: 2, tail: Array("/bin/x\0x\0unfinished".utf8))))
    #expect(truncated.arguments == ["x"])
  }

  @Test func inheritedSocketSharesID() throws {
    let (fd, port) = try listener(ipv6: false)
    defer { close(fd) }
    #expect(fcntl(fd, F_GETFD) & FD_CLOEXEC == 0)
    var child: pid_t = 0
    let argv = [strdup("/bin/sleep"), strdup("5"), nil]
    defer { for pointer in argv { free(pointer) } }
    let status = argv.withUnsafeBufferPointer {
      posix_spawn(&child, "/bin/sleep", nil, nil, $0.baseAddress!, nil)
    }
    try #require(status == 0)
    defer {
      _ = kill(child, SIGKILL)
      var status: Int32 = 0
      while waitpid(child, &status, 0) < 0 && errno == EINTR {}
    }
    let listeners = try LibprocProcessSource().listeners().filter { $0.port == port }
    let own = try #require(listeners.first { $0.pid == getpid() })
    let inherited = try #require(listeners.first { $0.pid == child })
    #expect(own.socketID != nil)
    #expect(own.socketID == inherited.socketID)
  }

  @Test func findsOwnLoopbackListener() throws {
    let (fd, port) = try listener(ipv6: false)
    defer { close(fd) }
    #expect(
      try LibprocProcessSource().listeners().contains {
        $0.pid == getpid() && $0.port == port && $0.address == "127.0.0.1"
      })
  }

  @Test func findsOwnIPv6Listener() throws {
    let (fd, port) = try listener(ipv6: true)
    defer { close(fd) }
    #expect(
      try LibprocProcessSource().listeners().contains {
        $0.pid == getpid() && $0.port == port && $0.address == "::1"
      })
  }

  @Test func readsOwnProcessRecord() throws {
    let record = try #require(LibprocProcessSource().process(getpid()))
    #expect(record.cwd == FileManager.default.currentDirectoryPath)
    #expect(record.uid == getuid())
    #expect(record.parentPID == getppid())
    #expect(record.arguments?.isEmpty == false)
    #expect(record.executablePath?.isEmpty == false)
    #expect(try #require(record.startedAt) < Date())
  }

  @Test func exitedPidIsNil() throws {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    try child.run()
    let pid = child.processIdentifier
    child.waitUntilExit()
    #expect(LibprocProcessSource().process(pid) == nil)
  }

  @Test func localFileProbeReadsAndChecks() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "doorplate-files-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("package.json")
    try "{\"name\":\"test\"}".write(to: file, atomically: true, encoding: .utf8)
    let probe = LocalFileProbe()
    #expect(probe.homeDirectory == NSHomeDirectory())
    #expect(probe.presence(file.path) == .present)
    #expect(probe.read(file.path) == "{\"name\":\"test\"}")
    #expect(probe.presence(directory.appendingPathComponent("missing").path) == .absent)
    #expect(probe.read(directory.appendingPathComponent("missing").path) == nil)
    #expect(probe.presence(file.appendingPathComponent("child").path) == .absent)
    try #require(chmod(directory.path, 0) == 0)
    defer { _ = chmod(directory.path, 0o700) }
    #expect(probe.presence(file.path) == .denied)
    #expect(probe.read(file.path) == nil)
  }

  private func listener(ipv6: Bool) throws -> (Int32, UInt16) {
    let fd = socket(ipv6 ? AF_INET6 : AF_INET, SOCK_STREAM, 0)
    try #require(fd >= 0)
    do {
      var port: UInt16 = 0
      if ipv6 {
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = sa_family_t(AF_INET6)
        address.sin6_addr = in6addr_loopback
        try withUnsafeMutablePointer(to: &address) { pointer in
          try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            try #require(bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) == 0)
            var size = socklen_t(MemoryLayout<sockaddr_in6>.size)
            try #require(getsockname(fd, $0, &size) == 0)
          }
        }
        port = UInt16(bigEndian: address.sin6_port)
      } else {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)
        try withUnsafeMutablePointer(to: &address) { pointer in
          try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            try #require(bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0)
            var size = socklen_t(MemoryLayout<sockaddr_in>.size)
            try #require(getsockname(fd, $0, &size) == 0)
          }
        }
        port = UInt16(bigEndian: address.sin_port)
      }
      try #require(listen(fd, 1) == 0)
      return (fd, port)
    } catch {
      close(fd)
      throw error
    }
  }
}
