import Foundation

enum DockerJSON {
  private struct ListedContainer: Decodable {
    var id: String
    var names: [String]?
    var image: String
    var labels: [String: String]?
    var ports: [PublishedPort]?
    enum CodingKeys: String, CodingKey {
      case id = "Id"
      case names = "Names"
      case image = "Image"
      case labels = "Labels"
      case ports = "Ports"
    }
  }
  private struct PublishedPort: Decodable {
    var ip: String?
    var publicPort: UInt16?
    var type: String
    enum CodingKeys: String, CodingKey {
      case ip = "IP"
      case publicPort = "PublicPort"
      case type = "Type"
    }
  }
  private struct Inspect: Decodable {
    struct StateInfo: Decodable {
      var startedAt: String?
      enum CodingKeys: String, CodingKey { case startedAt = "StartedAt" }
    }
    var state: StateInfo?
    enum CodingKeys: String, CodingKey { case state = "State" }
  }

  static func containers(_ list: Data) throws -> [Container] {
    try JSONDecoder().decode([ListedContainer].self, from: list).map { item in
      var ports: [UInt16: Exposure] = [:]
      for binding in item.ports ?? [] where binding.type == "tcp" {
        guard let port = binding.publicPort else { continue }
        let exposure: Exposure =
          binding.ip == "127.0.0.1" || binding.ip == "::1" ? .loopback : .network
        ports[port] = ports[port] == .network ? .network : exposure
      }
      return Container(
        id: item.id, name: item.names?.first ?? "", image: item.image,
        composeProject: item.labels?["com.docker.compose.project"],
        composeService: item.labels?["com.docker.compose.service"],
        composeWorkingDir: item.labels?["com.docker.compose.project.working_dir"],
        publishedPorts: ports.keys.sorted().map {
          PortBinding(port: $0, exposure: ports[$0]!, role: nil)
        })
    }
  }

  static func startedAt(_ inspect: Data) throws -> Date? {
    guard var text = try JSONDecoder().decode(Inspect.self, from: inspect).state?.startedAt,
      !text.hasPrefix("0001-01-01T00:00:00")
    else { return nil }
    if let dot = text.firstIndex(of: ".") {
      let fractionStart = text.index(after: dot)
      let fractionEnd = text[fractionStart...].firstIndex(where: { !$0.isNumber }) ?? text.endIndex
      text =
        String(text[...dot]) + String(text[fractionStart..<fractionEnd].prefix(3))
        + text[fractionEnd...]
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions =
      text.contains(".")
      ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
    return formatter.date(from: text)
  }
}
