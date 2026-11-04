import Foundation

enum DockerJSON {
  private struct ListedContainer: Decodable {
    var Id: String
    var Names: [String]?
    var Image: String
    var Labels: [String: String]?
    var Ports: [PublishedPort]?
  }
  private struct PublishedPort: Decodable {
    var IP: String?
    var PublicPort: UInt16?
    var `Type`: String
  }
  private struct Inspect: Decodable {
    struct StateInfo: Decodable { var StartedAt: String? }
    var State: StateInfo?
  }

  static func containers(_ list: Data) throws -> [Container] {
    try JSONDecoder().decode([ListedContainer].self, from: list).map { item in
      var ports: [UInt16: Exposure] = [:]
      for binding in item.Ports ?? [] where binding.Type == "tcp" {
        guard let port = binding.PublicPort else { continue }
        let exposure: Exposure =
          binding.IP == "127.0.0.1" || binding.IP == "::1" ? .loopback : .network
        ports[port] = ports[port] == .network ? .network : exposure
      }
      return Container(
        id: item.Id, name: item.Names?.first ?? "", image: item.Image,
        composeProject: item.Labels?["com.docker.compose.project"],
        composeService: item.Labels?["com.docker.compose.service"],
        composeWorkingDir: item.Labels?["com.docker.compose.project.working_dir"],
        publishedPorts: ports.keys.sorted().map {
          PortBinding(port: $0, exposure: ports[$0]!, role: nil)
        })
    }
  }

  static func startedAt(_ inspect: Data) throws -> Date? {
    guard var text = try JSONDecoder().decode(Inspect.self, from: inspect).State?.StartedAt,
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
