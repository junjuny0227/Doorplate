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
  public static func empty(title: String, link: URL) -> String { "" }

  public static func adding(_ item: AppcastItem, to xml: String) throws -> String { xml }

  public static func parseSignOutput(_ output: String) throws -> (edSignature: String, length: Int) {
    ("", 0)
  }
}
