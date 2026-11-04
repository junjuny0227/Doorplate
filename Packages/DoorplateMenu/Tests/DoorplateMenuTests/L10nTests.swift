import Foundation
import Testing

@testable import DoorplateMenu

struct L10nTests {
  private func strings(_ language: String) throws -> [String: String] {
    let folder = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    let dictionary = try #require(
      NSDictionary(contentsOf: folder.appendingPathComponent("Localizable.strings")))
    return try #require(dictionary as? [String: String])
  }

  @Test func everyKeyHasKorean() throws {
    let english = try strings("en")
    let korean = try strings("ko")
    #expect(!english.isEmpty)
    #expect(Set(english.keys) == Set(korean.keys))
    #expect(Set(english.keys) == Set(L10n.Key.allCases.map(\.rawValue)))
    #expect(korean.values.allSatisfy { !$0.isEmpty })
  }

  @Test func formatSpecifiersMatch() throws {
    let english = try strings("en")
    let korean = try strings("ko")
    let pattern = try NSRegularExpression(pattern: "%[@d]")
    func specifiers(_ value: String) -> [String] {
      pattern.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
        (value as NSString).substring(with: $0.range)
      }
    }
    for key in L10n.Key.allCases {
      #expect(
        specifiers(try #require(english[key.rawValue]))
          == specifiers(try #require(korean[key.rawValue])))
    }
  }

  @Test func koreanLoads() throws {
    let folder = try #require(Bundle.module.url(forResource: "ko", withExtension: "lproj"))
    let bundle = try #require(Bundle(url: folder))
    #expect(bundle.localizedString(forKey: "menu.empty", value: nil, table: nil) == "실행 중인 서버 없음")
    #expect(bundle.localizedString(forKey: "row.longRunning", value: nil, table: nil) == "%@째")
  }

  @Test func textAndFormatting() {
    #expect(L10n.text(.menuEmpty) == "No servers running")
    #expect(L10n.format(.headerRunning, 3) == "Running · 3")
    #expect(L10n.format(.rowStop, 80, "shop") == "Stop 80 shop")
    #expect(L10n.format(.alertCouldNotStop, "shop") == "Couldn't stop shop.")
  }
}
