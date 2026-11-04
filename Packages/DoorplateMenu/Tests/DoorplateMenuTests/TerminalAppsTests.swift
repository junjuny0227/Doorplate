import Foundation
import Testing

@testable import DoorplateMenu

struct TerminalAppsTests {
  @Test func installedKeepsKnownOrder() {
    let installed = TerminalApps.installed { bundleID in
      ["com.googlecode.iterm2", "com.mitchellh.ghostty"].contains(bundleID)
        ? URL(fileURLWithPath: "/Applications/\(bundleID).app") : nil
    }
    #expect(
      installed.map(\.bundleID) == [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
      ])
  }

  @Test func missingTerminalFallsBackToTerminal() {
    let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    let resolved = TerminalApps.resolved(selected: "com.googlecode.iterm2") { bundleID in
      bundleID == "com.apple.Terminal" ? terminalURL : nil
    }
    #expect(resolved == terminalURL)
  }
}
