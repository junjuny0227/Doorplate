import Foundation

public enum PortRoleDetector {
  public static func assign(_ listeners: [Listener], arguments: [String]) -> (
    primary: PortBinding, extras: [PortBinding]
  ) {
    precondition(!listeners.isEmpty, "listeners must not be empty")

    var exposures: [UInt16: Exposure] = [:]
    for listener in listeners {
      if listener.exposure == .network || exposures[listener.port] == nil {
        exposures[listener.port] = listener.exposure
      }
    }

    var roles: [UInt16: PortRole] = [:]
    for argument in arguments {
      if argument.hasPrefix("-agentlib:jdwp=") || argument.hasPrefix("-Xrunjdwp:") {
        let payload = argument.components(separatedBy: "address=").dropFirst().first
        if let payload,
          let address = payload.split(separator: ",", maxSplits: 1).first,
          let port = address.split(separator: ":").last.flatMap({ UInt16($0) }),
          exposures[port] != nil
        {
          roles[port] = .debugger
        }
      }

      if argument == "--inspect" || argument == "--inspect-brk" {
        if exposures[9229] != nil { roles[9229] = .inspector }
      } else if argument.hasPrefix("--inspect=") || argument.hasPrefix("--inspect-brk=") {
        guard let value = argument.split(separator: "=", maxSplits: 1).last,
          let port = value.split(separator: ":").last.flatMap({ UInt16($0) }),
          exposures[port] != nil
        else { continue }
        roles[port] = .inspector
      }
    }

    if exposures[35729] != nil { roles[35729] = .liveReload }
    let bindings = exposures.keys.sorted().map { port in
      PortBinding(port: port, exposure: exposures[port]!, role: roles[port])
    }
    let primaryIndex = bindings.firstIndex(where: { $0.role == nil }) ?? 0
    var ordered = bindings
    let primary = ordered.remove(at: primaryIndex)
    return (primary, ordered)
  }
}

public enum HTTPGuess {
  private static let nonHTTPPorts: Set<UInt16> = [5432, 3306, 6379, 27017, 9092, 11211]
  private static let nonHTTPImages: Set<String> = [
    "postgres", "postgresql", "mysql", "mariadb", "redis", "valkey", "mongo", "mongodb",
    "kafka", "cp-kafka", "memcached",
  ]

  public static func likelyHTTP(port: UInt16, image: String?) -> Bool {
    guard !nonHTTPPorts.contains(port) else { return false }
    if let image {
      let shortName = image.split(separator: "/").last.map(String.init)?.split(separator: ":").first
        .map(String.init)
      if let shortName, nonHTTPImages.contains(shortName) { return false }
    }
    return true
  }
}
