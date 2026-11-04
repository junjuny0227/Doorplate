import Foundation

public final class RecordingFileProbe: FileProbe, @unchecked Sendable {
  private let wrapped: any FileProbe
  private let lock = NSLock()
  private var contents: [String: String] = [:]
  private var deniedPaths: Set<String> = []

  public init(wrapping: any FileProbe) { wrapped = wrapping }

  public var homeDirectory: String { wrapped.homeDirectory }
  public var recorded: [String: String] { lock.withLock { contents } }
  public var denied: [String] { lock.withLock { deniedPaths.sorted() } }

  public func presence(_ path: String) -> FilePresence {
    let result = wrapped.presence(path)
    lock.withLock {
      switch result {
      case .present:
        if contents[path] == nil { contents[path] = "" }
      case .denied:
        deniedPaths.insert(path)
      case .absent:
        break
      }
    }
    return result
  }

  public func read(_ path: String) -> String? {
    let result = wrapped.read(path)
    if let result { lock.withLock { contents[path] = result } }
    return result
  }
}
