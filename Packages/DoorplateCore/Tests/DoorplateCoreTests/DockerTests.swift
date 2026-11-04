import Darwin
import Foundation
import Testing

@testable import DoorplateCore

struct DockerTests {
  @Test func parsesContentLengthAndChunked() throws {
    let body = Data("hello π".utf8)
    let length = Data("HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n".utf8) + body
    let chunked = Data("HTTP/1.1 200 OK\r\ntRaNsFeR-EnCoDiNg: chunked\r\n\r\n4;ext=yes\r\nhell\r\n4\r\no π\r\n0\r\nX-Trailer: yes\r\n\r\n".utf8)
    #expect(try HTTPResponse.parse(length).body == body)
    #expect(try HTTPResponse.parse(chunked).body == body)
    let eof = try HTTPResponse.parse(Data("HTTP/1.1 404 Not Found\r\n\r\nmissing".utf8))
    #expect(eof.status == 404)
    #expect(eof.body == Data("missing".utf8))
  }

  @Test(arguments: [
    "garbage", "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nx",
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n-1\r\nx\r\n",
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nx",
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n"
  ])
  func rejectsMalformedHTTP(wire: String) {
    #expect(throws: (any Error).self) { try HTTPResponse.parse(Data(wire.utf8)) }
  }
}
