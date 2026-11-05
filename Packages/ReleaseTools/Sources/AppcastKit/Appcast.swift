import Foundation

public struct AppcastItem: Equatable {
  public var version: String
  public var build: String
  public var url: URL
  public var length: Int
  public var edSignature: String
  public var minimumSystemVersion: String = "14.0"
  public var publishedAt: Date

  public init(
    version: String, build: String, url: URL, length: Int, edSignature: String,
    minimumSystemVersion: String = "14.0", publishedAt: Date
  ) {
    self.version = version
    self.build = build
    self.url = url
    self.length = length
    self.edSignature = edSignature
    self.minimumSystemVersion = minimumSystemVersion
    self.publishedAt = publishedAt
  }
}

public enum Appcast {
  private static let sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"

  private enum InvalidInput: Error {
    case appcast, signOutput
  }

  public static func empty(title: String, link: URL) -> String {
    let root = XMLElement(name: "rss")
    root.addAttribute(XMLNode.attribute(withName: "version", stringValue: "2.0") as! XMLNode)
    root.addNamespace(XMLNode.namespace(withName: "sparkle", stringValue: sparkle) as! XMLNode)
    let channel = XMLElement(name: "channel")
    channel.addChild(XMLElement(name: "title", stringValue: title))
    channel.addChild(XMLElement(name: "link", stringValue: link.absoluteString))
    root.addChild(channel)
    return serialized(XMLDocument(rootElement: root))
  }

  public static func adding(_ item: AppcastItem, to xml: String) throws -> String {
    let document = try XMLDocument(xmlString: xml, options: [.nodeLoadExternalEntitiesNever])
    guard let root = document.rootElement(), root.name == "rss",
      let channel = root.elements(forName: "channel").first
    else { throw InvalidInput.appcast }
    root.addNamespace(XMLNode.namespace(withName: "sparkle", stringValue: sparkle) as! XMLNode)

    for existing in channel.elements(forName: "item") {
      if existing.elements(forLocalName: "version", uri: sparkle).first?.stringValue == item.build {
        existing.detach()
      }
    }

    let entry = XMLElement(name: "item")
    entry.addChild(XMLElement(name: "title", stringValue: "Doorplate \(item.version)"))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    entry.addChild(
      XMLElement(name: "pubDate", stringValue: formatter.string(from: item.publishedAt)))
    entry.addChild(XMLElement(name: "sparkle:version", stringValue: item.build))
    entry.addChild(XMLElement(name: "sparkle:shortVersionString", stringValue: item.version))
    entry.addChild(
      XMLElement(name: "sparkle:minimumSystemVersion", stringValue: item.minimumSystemVersion))
    let enclosure = XMLElement(name: "enclosure")
    for (name, value) in [
      ("url", item.url.absoluteString), ("length", String(item.length)),
      ("type", "application/octet-stream"), ("sparkle:edSignature", item.edSignature),
    ] {
      enclosure.addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
    }
    entry.addChild(enclosure)
    channel.insertChild(entry, at: 0)
    return serialized(document)
  }

  public static func parseSignOutput(_ output: String) throws -> (edSignature: String, length: Int)
  {
    let pattern = #"\A\s*sparkle:edSignature="([A-Za-z0-9+/=]+)"\s+length="([0-9]+)"\s*\z"#
    let expression = try NSRegularExpression(pattern: pattern)
    guard
      let match = expression.firstMatch(
        in: output, range: NSRange(output.startIndex..., in: output)),
      let signatureRange = Range(match.range(at: 1), in: output),
      let lengthRange = Range(match.range(at: 2), in: output),
      let length = Int(output[lengthRange])
    else { throw InvalidInput.signOutput }
    return (String(output[signatureRange]), length)
  }

  private static func serialized(_ document: XMLDocument) -> String {
    document.version = "1.0"
    document.characterEncoding = "UTF-8"
    return document.xmlString(options: [.nodePrettyPrint]) + "\n"
  }
}
