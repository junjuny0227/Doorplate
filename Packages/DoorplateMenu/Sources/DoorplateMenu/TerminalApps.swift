import Foundation

public struct TerminalApp: Equatable, Sendable {
  public var bundleID: String
  public var name: String

  public init(bundleID: String, name: String) {
    self.bundleID = bundleID
    self.name = name
  }
}

public enum TerminalApps {
  public static let known: [TerminalApp] = [
    TerminalApp(bundleID: "com.apple.Terminal", name: "Terminal"),
    TerminalApp(bundleID: "com.googlecode.iterm2", name: "iTerm"),
    TerminalApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
    TerminalApp(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
    TerminalApp(bundleID: "com.github.wez.wezterm", name: "WezTerm"),
    TerminalApp(bundleID: "net.kovidgoyal.kitty", name: "kitty"),
  ]

  public static func installed(lookup: (String) -> URL?) -> [TerminalApp] {
    known.filter { $0.bundleID == "com.apple.Terminal" || lookup($0.bundleID) != nil }
  }

  public static func resolved(selected: String, lookup: (String) -> URL?) -> URL {
    if let url = lookup(selected) { return url }
    return lookup("com.apple.Terminal")
      ?? URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
  }
}
