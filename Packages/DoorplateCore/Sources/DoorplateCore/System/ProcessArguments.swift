enum ProcessArguments {
  static func parse(_ buffer: [UInt8]) -> (executable: String, arguments: [String])? {
    let headerSize = MemoryLayout<Int32>.size
    guard buffer.count >= headerSize,
      let pathEnd = buffer[headerSize...].firstIndex(of: 0)
    else { return nil }
    let argc = buffer.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
    let executable = String(decoding: buffer[headerSize..<pathEnd], as: UTF8.self)
    var cursor = pathEnd + 1
    while cursor < buffer.count && buffer[cursor] == 0 { cursor += 1 }
    var arguments: [String] = []
    // Stop at rewritten-title padding; never walk past argc into the environment.
    while cursor < buffer.count && buffer[cursor] != 0 && arguments.count < argc {
      let start = cursor
      while cursor < buffer.count && buffer[cursor] != 0 { cursor += 1 }
      guard cursor < buffer.count else { break }
      arguments.append(String(decoding: buffer[start..<cursor], as: UTF8.self))
      cursor += 1
    }
    return (executable, arguments)
  }
}
