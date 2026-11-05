import Foundation
import Testing

@testable import DoorplateMenu

struct L10nTests {
  private func strings(_ language: String) throws -> [String: String] {
    // SwiftPM versions differ in whether localization directory names retain their case.
    // Find the exact language without Bundle's fallback to English masking a missing resource.
    let resources = try #require(Bundle.module.resourceURL)
    let folders = try FileManager.default.contentsOfDirectory(
      at: resources, includingPropertiesForKeys: nil)
    let folder = try #require(
      folders.first {
        $0.lastPathComponent.caseInsensitiveCompare("\(language).lproj") == .orderedSame
      })
    let dictionary = try #require(
      NSDictionary(contentsOf: folder.appendingPathComponent("Localizable.strings")))
    return try #require(dictionary as? [String: String])
  }

  /// Every printf-style specifier in order, including positional (`%1$@`), length modifiers
  /// (`%lld`) and literal `%%`, so a translation cannot drop, add or reorder an argument.
  private func specifiers(_ value: String) throws -> [String] {
    let pattern = try NSRegularExpression(
      pattern: #"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfFeEgGcCsSp%]"#)
    return pattern.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
      (value as NSString).substring(with: $0.range)
    }
  }

  /// The repository root, found from this file so the App target's resources can be read too.
  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // DoorplateMenuTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // DoorplateMenu
      .deletingLastPathComponent()  // Packages
      .deletingLastPathComponent()
  }

  @Test(arguments: ["en", "ko", "ja", "zh-Hans"])
  func everyLanguageHasEveryKey(_ language: String) throws {
    let english = try strings("en")
    let localized = try strings(language)
    #expect(!english.isEmpty)
    #expect(Set(english.keys) == Set(localized.keys))
    #expect(Set(english.keys) == Set(L10n.Key.allCases.map(\.rawValue)))
    #expect(localized.values.allSatisfy { !$0.isEmpty })
  }

  @Test(arguments: ["en", "ko", "ja", "zh-Hans"])
  func formatSpecifiersMatch(_ language: String) throws {
    let english = try strings("en")
    let localized = try strings(language)
    for key in L10n.Key.allCases {
      let en = try specifiers(try #require(english[key.rawValue]))
      let translated = try specifiers(try #require(localized[key.rawValue]))
      #expect(en == translated, "\(language) \(key.rawValue): \(en) vs \(translated)")
    }
  }

  @Test(arguments: ["ko", "ja", "zh-Hans"])
  func infoPlistUsageDescriptionKeysMatch(_ language: String) throws {
    let resources = repositoryRoot.appendingPathComponent("App/Resources")
    let info = try #require(
      NSDictionary(contentsOf: resources.appendingPathComponent("Info.plist")) as? [String: Any])
    let localized = try #require(
      NSDictionary(
        contentsOf: resources.appendingPathComponent("\(language).lproj/InfoPlist.strings"))
        as? [String: String])
    let usageKeys = Set(info.keys.filter { $0.hasSuffix("UsageDescription") })
    #expect(!usageKeys.isEmpty)
    #expect(Set(localized.keys) == usageKeys)
    #expect(localized.values.allSatisfy { !$0.isEmpty })
    for (key, value) in localized {
      #expect(value != info[key] as? String, "\(language) \(key) is not translated")
    }
  }

  @Test func specifierPatternSeesLengthModifiersAndPositions() throws {
    #expect(try specifiers("Stop %lld %1$@ 50%%") == ["%lld", "%1$@", "%%"])
  }

  @Test func koreanIsTranslatedExceptNames() throws {
    let english = try strings("en")
    let korean = try strings("ko")
    // Product names stay in English in both languages.
    let sameInBothLanguages: Set = ["menu.docker", "role.liveReload"]
    for key in L10n.Key.allCases where !sameInBothLanguages.contains(key.rawValue) {
      #expect(english[key.rawValue] != korean[key.rawValue], "\(key.rawValue) is not translated")
    }
  }

  @Test func koreanHasNoStrayEnglish() throws {
    let allowed = [
      "Doorplate", "Docker", "Compose", "Finder", "PID", "AirPlay", "AirDrop", "Handoff", "macOS",
      "LiveReload",
    ]
    for (key, value) in try strings("ko") {
      var rest = value
      for specifier in try specifiers(value) {
        rest = rest.replacingOccurrences(of: specifier, with: "")
      }
      for word in allowed { rest = rest.replacingOccurrences(of: word, with: "") }
      #expect(rest.range(of: "[A-Za-z]", options: .regularExpression) == nil, "\(key): \(value)")
    }
  }

  @Test func koreanFollowsSpecWording() throws {
    // Spec sections 8 (menu) and 11 (settings) name these Korean strings.
    let korean = try strings("ko")
    let spec: [String: String] = [
      "header.running": "실행 중 · %d",
      "menu.hidden": "숨김 %d개",
      "menu.settings": "설정…",
      "menu.quit": "Doorplate 종료",
      "row.stop": "종료 · %d %@",
      "row.longRunning": "%@째",
      "system.airplay": "AirPlay 수신 (macOS)",
      "exposure.network": "네트워크에 열림",
      "sub.openInBrowser": "브라우저에서 열기",
      "sub.showInFinder": "Finder에서 보기",
      "sub.openInTerminal": "터미널에서 열기",
      "sub.copyAddress": "주소 복사",
      "sub.showComposeFolder": "Compose 폴더를 Finder에서 보기",
      "sub.stopWithPID": "종료 (PID %d)",
      "sub.stopContainer": "컨테이너 정지",
      "role.debugger": "디버거",
      "alert.forceStop": "강제 종료",
      "alert.keepWaiting": "기다리기",
      "settings.openAtLogin": "로그인 시 실행",
      "settings.longRunning": "오래 켜짐 기준",
      "settings.showDevTools": "개발 도구 포트 표시",
      "settings.showOtherApps": "다른 앱 포트 표시",
      "settings.terminal": "터미널 앱",
      "settings.autoUpdate": "업데이트 자동 확인",
    ]
    for (key, value) in spec {
      #expect(korean[key] == value, "\(key)")
    }
  }

  @Test func infoPlistUsageDescriptionsHaveKorean() throws {
    let resources = repositoryRoot.appendingPathComponent("App/Resources")
    let info = try #require(
      NSDictionary(contentsOf: resources.appendingPathComponent("Info.plist")) as? [String: Any])
    let korean = try #require(
      NSDictionary(contentsOf: resources.appendingPathComponent("ko.lproj/InfoPlist.strings"))
        as? [String: String])
    let usageKeys = Set(info.keys.filter { $0.hasSuffix("UsageDescription") })
    #expect(!usageKeys.isEmpty)
    #expect(Set(korean.keys) == usageKeys)
    for (key, value) in korean {
      #expect(value != info[key] as? String, "\(key) is not translated")
      #expect(value.range(of: "[가-힣]", options: .regularExpression) != nil, "\(key)")
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
    #expect(L10n.format(.rowStop, 5173, "shop") == "Stop 5173 shop")
    #expect(L10n.format(.alertCouldNotStop, "shop") == "Couldn't stop shop.")
    #expect(L10n.format(.alertLoginFailed, "x") == "Couldn't change the login item: x")
  }
}
