import Foundation

public struct ProjectInfo: Sendable, Equatable {
  public var name: String
  public var directory: String
  public var repositoryRoot: String?
  public init(name: String, directory: String, repositoryRoot: String?) {
    self.name = name
    self.directory = directory
    self.repositoryRoot = repositoryRoot
  }
}

public struct ProjectResolver: Sendable {
  private let files: any FileProbe
  let homeDirectory: String
  public init(files: any FileProbe) {
    self.files = files
    self.homeDirectory = files.homeDirectory
  }
  public func resolve(startingAt directory: String) -> ProjectInfo? {
    let start = standardized(directory)
    let home = standardized(files.homeDirectory)
    guard start != "/", start != home else { return nil }
    var current = start
    while current != "/", current != home {
      for (file, reader) in checks {
        let path = join(current, file)
        let presence = files.presence(path)
        if presence == .denied {
          return inaccessibleProject(startingAt: start)
        }
        guard presence == .present else { continue }
        if file == ".git" {
          return ProjectInfo(
            name: leaf(current), directory: current, repositoryRoot: gitRoot(from: current))
        }
        if let text = files.read(path), let name = reader(text), !name.isEmpty {
          return ProjectInfo(name: name, directory: current, repositoryRoot: gitRoot(from: current))
        }
      }
      current = parent(current)
    }
    return nil
  }
  /// Shared fallback for denied access and protected lookups still awaiting permission.
  /// This only derives a name from the path; it must never probe the filesystem.
  func inaccessibleProject(startingAt directory: String) -> ProjectInfo? {
    let start = standardized(directory)
    guard start != "/", start != standardized(homeDirectory) else { return nil }
    return ProjectInfo(name: leaf(start), directory: start, repositoryRoot: nil)
  }

  public static func startDirectory(for process: ProcessRecord) -> String? {
    let args = process.arguments ?? []
    if let i = args.firstIndex(of: "-jar"), args.indices.contains(i + 1) {
      let jar = args[i + 1]
      if jar.hasPrefix("/") {
        return URL(fileURLWithPath: jar).standardizedFileURL.deletingLastPathComponent().path
      }
      guard let cwd = process.cwd else { return nil }
      return URL(fileURLWithPath: cwd).appendingPathComponent(jar).standardizedFileURL
        .deletingLastPathComponent().path
    }
    return process.cwd.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
  }
  private var checks: [(String, (String) -> String?)] {
    [
      ("package.json", ManifestName.packageJSON),
      ("Cargo.toml", { ManifestName.toml($0, section: "package") }),
      ("pyproject.toml", { ManifestName.toml($0, section: "project") }),
      ("settings.gradle.kts", ManifestName.gradle), ("settings.gradle", ManifestName.gradle),
      ("pom.xml", ManifestName.maven), ("go.mod", ManifestName.goModule), (".git", { _ in nil }),
    ]
  }
  private func gitRoot(from dir: String) -> String? {
    var path = dir
    var home = standardized(files.homeDirectory)
    while path != "/", path != home {
      let presence = files.presence(join(path, ".git"))
      if presence == .denied { return nil }
      if presence == .present { return path }
      path = parent(path)
    }
    return nil
  }
  private func leaf(_ p: String) -> String { URL(fileURLWithPath: p).lastPathComponent }
  private func join(_ a: String, _ b: String) -> String {
    URL(fileURLWithPath: a).appendingPathComponent(b).path
  }
  private func parent(_ p: String) -> String {
    URL(fileURLWithPath: p).deletingLastPathComponent().path
  }
  private func standardized(_ p: String) -> String {
    URL(fileURLWithPath: p).standardizedFileURL.path
  }
}
