import Foundation

enum HTTPResponse {
  enum ParseError: Error { case invalid }

  static func parse(_ data: Data) throws -> (status: Int, body: Data) {
    let crlf = Data("\r\n".utf8)
    guard let separator = data.range(of: Data("\r\n\r\n".utf8)),
      let header = String(data: data[..<separator.lowerBound], encoding: .utf8)
    else { throw ParseError.invalid }
    let lines = header.components(separatedBy: "\r\n")
    let statusLine = lines[0].split(separator: " ")
    guard statusLine.count >= 2, statusLine[0].hasPrefix("HTTP/"),
      let status = Int(statusLine[1]), (100...599).contains(status)
    else { throw ParseError.invalid }
    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
      let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2 else { throw ParseError.invalid }
      headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
    }
    let encoded = Data(data[separator.upperBound...])
    if headers["transfer-encoding"]?.split(separator: ",").contains(where: {
      $0.trimmingCharacters(in: .whitespaces).lowercased() == "chunked"
    }) == true {
      var offset = encoded.startIndex
      var body = Data()
      while offset < encoded.endIndex {
        guard let line = encoded.range(of: crlf, in: offset..<encoded.endIndex),
          let text = String(data: encoded[offset..<line.lowerBound], encoding: .utf8),
          let token = text.split(separator: ";", maxSplits: 1).first,
          !token.isEmpty, token.allSatisfy({ $0.isASCII && $0.isHexDigit }),
          let size = Int(token, radix: 16)
        else { throw ParseError.invalid }
        offset = line.upperBound
        if size == 0 {
          // Consume the trailer section, including its final empty line.
          while let trailer = encoded.range(of: crlf, in: offset..<encoded.endIndex) {
            if trailer.lowerBound == offset { return (status, body) }
            offset = trailer.upperBound
          }
          throw ParseError.invalid
        }
        guard encoded.endIndex - offset >= 2, size <= encoded.endIndex - offset - 2 else {
          throw ParseError.invalid
        }
        body.append(encoded[offset..<(offset + size)])
        offset += size
        guard encoded[offset..<(offset + 2)] == crlf else { throw ParseError.invalid }
        offset += 2
      }
      throw ParseError.invalid
    }
    if let value = headers["content-length"] {
      guard let length = Int(value), length >= 0, encoded.count == length else {
        throw ParseError.invalid
      }
    }
    return (status, encoded)
  }
}
