import Foundation
import Testing

@testable import AppcastKit

struct AppcastTests {
  private let sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"

  private func item(version: String = "0.1.0", build: String = "1", signature: String = "abc")
    -> AppcastItem
  {
    AppcastItem(
      version: version, build: build,
      url: URL(string: "https://example.com/D.zip?first=1&second=2")!, length: 1234,
      edSignature: signature, publishedAt: Date(timeIntervalSince1970: 0))
  }

  private func empty() -> String {
    Appcast.empty(title: "Doorplate & friends", link: URL(string: "https://example.com")!)
  }

  @Test func emptyHasSparkleNamespace() throws {
    let document = try XMLDocument(xmlString: empty())
    let root = try #require(document.rootElement())
    #expect(root.name == "rss")
    #expect(root.attribute(forName: "version")?.stringValue == "2.0")
    #expect(root.namespace(forPrefix: "sparkle")?.stringValue == sparkle)
    #expect(try document.nodes(forXPath: "/rss/channel/item").isEmpty)
    #expect(try document.nodes(forXPath: "/rss/channel/title").first?.stringValue == "Doorplate & friends")
  }

  @Test func writesEnclosureAttributes() throws {
    let document = try XMLDocument(xmlString: Appcast.adding(item(), to: empty()))
    let entry = try #require(document.nodes(forXPath: "/rss/channel/item").first as? XMLElement)
    let enclosure = try #require(entry.elements(forName: "enclosure").first)
    #expect(enclosure.attribute(forName: "url")?.stringValue == item().url.absoluteString)
    #expect(enclosure.attribute(forName: "length")?.stringValue == "1234")
    #expect(enclosure.attribute(forName: "type")?.stringValue == "application/octet-stream")
    #expect(enclosure.attribute(forLocalName: "edSignature", uri: sparkle)?.stringValue == "abc")
    #expect(entry.elements(forLocalName: "version", uri: sparkle).first?.stringValue == "1")
    #expect(entry.elements(forLocalName: "shortVersionString", uri: sparkle).first?.stringValue == "0.1.0")
    #expect(entry.elements(forLocalName: "minimumSystemVersion", uri: sparkle).first?.stringValue == "14.0")
    #expect(entry.elements(forName: "pubDate").first?.stringValue == "Thu, 01 Jan 1970 00:00:00 +0000")
  }

  @Test func keepsExistingItems() throws {
    let original = try Appcast.adding(item(), to: empty())
    let updated = try Appcast.adding(item(version: "0.1.1", build: "2"), to: original)
    let document = try XMLDocument(xmlString: updated)
    let entries = try document.nodes(forXPath: "/rss/channel/item").compactMap { $0 as? XMLElement }
    #expect(entries.count == 2)
    #expect(entries.first?.elements(forLocalName: "shortVersionString", uri: sparkle).first?.stringValue == "0.1.1")
    #expect(entries.last?.elements(forLocalName: "shortVersionString", uri: sparkle).first?.stringValue == "0.1.0")
    #expect(try document.nodes(forXPath: "/rss/channel/title").first?.stringValue == "Doorplate & friends")
  }

  @Test func replacesSameBuild() throws {
    let original = try Appcast.adding(item(), to: empty())
    let newer = try Appcast.adding(item(version: "0.1.1", build: "2"), to: original)
    let updated = try Appcast.adding(item(signature: "replacement+/="), to: newer)
    let document = try XMLDocument(xmlString: updated)
    let entries = try document.nodes(forXPath: "/rss/channel/item").compactMap { $0 as? XMLElement }
    #expect(entries.count == 2)
    let enclosure = try #require(entries.first?.elements(forName: "enclosure").first)
    #expect(enclosure.attribute(forLocalName: "edSignature", uri: sparkle)?.stringValue == "replacement+/=")
    #expect(entries.first?.elements(forLocalName: "version", uri: sparkle).first?.stringValue == "1")
  }

  @Test func parsesSignUpdateOutput() throws {
    let parsed = try Appcast.parseSignOutput("sparkle:edSignature=\"abc+/=\" length=\"1234\"")
    #expect(parsed.edSignature == "abc+/=")
    #expect(parsed.length == 1234)
    for invalid in [
      "", "unrelated", "sparkle:edSignature=\"abc\"", "length=\"1234\"",
      "sparkle:edSignature=\"\" length=\"12\"", "sparkle:edSignature=\"abc\" length=\"-1\"",
      "sparkle:edSignature=\"abc\" length=\"NaN\"",
      "sparkle:edSignature=\"abc\" length=\"999999999999999999999999999999\"",
      "sparkle:edSignature=\"abc\" length=\"12\" trailing",
    ] {
      #expect(throws: (any Error).self) { try Appcast.parseSignOutput(invalid) }
    }
  }
}
