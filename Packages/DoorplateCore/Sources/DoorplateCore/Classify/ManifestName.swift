import Foundation

// Internal name extraction helpers for the supported project manifests.
enum ManifestName {
  static func packageJSON(_ text: String) -> String? {
    guard let data = text.data(using: .utf8),
      let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return value["name"] as? String
  }

  static func toml(_ text: String, section: String) -> String? {
    var inSection = false
    for line in text.components(separatedBy: .newlines) {
      if let match = line.range(of: #"^\s*\[([^\]]+)\]\s*$"#, options: .regularExpression) {
        let header = String(line[match]).trimmingCharacters(in: .whitespacesAndNewlines)
        inSection = header == "[\(section)]"
        continue
      }
      if inSection, let value = capture(#"^\s*name\s*=\s*"([^"]+)""#, in: line) { return value }
    }
    return nil
  }

  static func gradle(_ text: String) -> String? {
    capture(#"rootProject\.name\s*=\s*[\"']([^\"']+)[\"']"#, in: text)
  }

  static func maven(_ text: String) -> String? {
    guard let data = text.data(using: .utf8) else { return nil }
    let parser = XMLParser(data: data)
    let delegate = MavenNameParser()
    parser.delegate = delegate
    return parser.parse() ? delegate.name : nil
  }

  static func goModule(_ text: String) -> String? {
    for line in text.components(separatedBy: .newlines) {
      if let module = capture(#"^\s*module\s+([^\s]+)"#, in: line) {
        return module.split(separator: "/").last.map(String.init)
      }
    }
    return nil
  }

  private static func capture(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[range])
  }
}

private final class MavenNameParser: NSObject, XMLParserDelegate {
  var name: String?
  private var depth = 0
  private var inRootArtifact = false
  private var capturing = false
  private var buffer = ""

  func parser(
    _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
  ) {
    depth += 1
    if depth == 2 && elementName == "artifactId" {
      inRootArtifact = true
      capturing = true
      buffer = ""
    }
  }
  func parser(_ parser: XMLParser, foundCharacters string: String) {
    if capturing { buffer += string }
  }
  func parser(
    _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if capturing && depth == 2 && elementName == "artifactId" {
      name = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
      capturing = false
    }
    depth -= 1
  }
}
