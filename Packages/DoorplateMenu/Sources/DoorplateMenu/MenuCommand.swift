import DoorplateCore
import Foundation

public struct EntryRef: Equatable, Sendable {
  public var id: String
  public var target: Target
  public var title: String
  public var port: UInt16

  public init(id: String, target: Target, title: String, port: UInt16) {
    self.id = id
    self.target = target
    self.title = title
    self.port = port
  }
}

public enum MenuCommand: Equatable, Sendable {
  case openInBrowser(URL)
  case revealInFinder(String)
  case openInTerminal(String)
  case copy(String)
  case stop(EntryRef)
  case openSettings, checkForUpdates
  case openUpdatePage(URL)
  case quit
}

public enum UpdateMenuItem: Equatable, Sendable {
  case checkForUpdates
  case available(version: String, page: URL)
  case pending(version: String)
  case none
}

public struct MenuState: Equatable, Sendable {
  public var stopping: Set<String> = []
  public var update: UpdateMenuItem = .checkForUpdates
  public init() {}
}

@MainActor public protocol MenuCommandHandler: AnyObject {
  func perform(_ command: MenuCommand)
}
