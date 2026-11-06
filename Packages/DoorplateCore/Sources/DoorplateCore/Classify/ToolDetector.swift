import Foundation

public struct ToolMatch: Sendable, Equatable {
  public var tool: String?
  public var section: Section
  public var title: String?
  /// False for processes Doorplate must never stop even when shown: container runtimes (every
  /// container would go down) and macOS services. Spec 3.
  public var stoppable: Bool
  public init(tool: String?, section: Section, title: String?, stoppable: Bool = true) {
    self.tool = tool
    self.section = section
    self.title = title
    self.stoppable = stoppable
  }
}

public enum ToolDetector {
  private enum Rule {
    case runtime, node, java, adb, cargo, python, ruby, ide, airplay, other, fallback
  }
  private static let rules: [Rule] = [
    .runtime, .node, .java, .adb, .cargo, .python, .ruby, .ide, .airplay, .other, .fallback,
  ]
  private static let frameworks = ["vite", "next", "nuxt", "astro", "remix", "webpack"]
  private static let ides = [
    "IntelliJ IDEA", "IntelliJ IDEA CE", "PyCharm", "WebStorm", "GoLand", "RustRover",
    "Android Studio", "Fleet", "Visual Studio Code", "Cursor", "Zed", "Xcode",
  ]
  private static let runtimes = ["Docker", "OrbStack", "Rancher Desktop", "Podman Desktop"]

  public static func detect(_ process: ProcessRecord, parent: ProcessRecord?, ports: [UInt16])
    -> ToolMatch
  {
    let path = process.executablePath ?? process.name
    let executable = URL(fileURLWithPath: path).lastPathComponent
    let args = process.arguments ?? []
    let app = outerApp(path)
    let enclosingApp = outermostApp(path)
    let ideApp =
      path.contains("Visual Studio Code.app/")
      ? "Visual Studio Code" : ides.first(where: { path.contains($0 + ".app/") })
    let resolvedIDE = ideApp.map { $0 == "Visual Studio Code" ? $0 : $0 }
    for rule in rules {
      switch rule {
      case .runtime:
        if let enclosingApp, runtimes.contains(enclosingApp) {
          return match("container runtime", .hidden(.otherApp), enclosingApp, stoppable: false)
        }
        if ["limactl", "vfkit", "gvproxy", "krunkit"].contains(executable)
          || executable.hasPrefix("qemu-system-")
        {
          return match("container runtime", .hidden(.otherApp), executable, stoppable: false)
        }
      case .node:
        if executable == "node" || process.name.hasPrefix("next-server")
          || args.first?.hasPrefix("next-server") == true
        {
          if process.name.hasPrefix("next-server") || args.first?.hasPrefix("next-server") == true {
            return match("next", .app)
          }
          for f in frameworks
          where args.contains(where: {
            $0.contains("/node_modules/\(f)/") || $0.hasSuffix("/node_modules/.bin/\(f)") || $0 == f
          }) { return match(f, .app) }
          return match("node", .app)
        }
      case .java:
        if executable == "java" || process.name == "java" {
          if args.contains(where: {
            $0.contains("org.gradle.launcher.daemon.bootstrap.GradleDaemon")
          }) {
            return match("gradle daemon", .hidden(.devTool))
          }
          if args.contains(where: { $0.contains("org.jetbrains.kotlin.daemon.KotlinCompileDaemon") }
          ) {
            return match("kotlin daemon", .hidden(.devTool))
          }
          let pa = parent?.arguments ?? []
          if pa.contains(where: { $0.contains("GradleDaemon") }) { return match("gradle", .app) }
          if pa.contains(where: { $0.contains("org.codehaus.plexus.classworlds.launcher.Launcher") }
          ) {
            return match("maven", .app)
          }
          return match("java", .app)
        }
      case .adb:
        if executable == "adb" { return match("adb", .hidden(.devTool), "adb") }
      case .cargo:
        if (parent?.arguments ?? []).contains("cargo") && (parent?.arguments ?? []).contains("run")
          || path.contains("/target/debug/") || path.contains("/target/release/")
        {
          return match("cargo", .app)
        }
      case .python:
        if process.name.lowercased().hasPrefix("python")
          || executable.lowercased().hasPrefix("python")
        {
          if args.contains("manage.py") && args.contains("runserver") {
            return match("django", .app)
          }
          for (needle, tool) in [
            ("uvicorn", "uvicorn"), ("flask", "flask"), ("gunicorn", "gunicorn"),
          ]
          where args.contains(where: {
            $0 == needle || $0.hasSuffix("/" + needle) || $0.contains(needle)
          }) { return match(tool, .app) }
          return match("python", .app)
        }
      case .ruby:
        if executable == "ruby" || process.name.hasPrefix("puma")
          || args.first?.hasPrefix("puma") == true
        {
          return match(
            args.contains(where: { $0.contains("puma") || $0.contains("rails") })
              ? "rails" : "ruby", .app)
        }
      case .ide:
        if let resolvedIDE {
          return ToolMatch(tool: resolvedIDE, section: .hidden(.devTool), title: resolvedIDE)
        }
      case .airplay:
        if process.name == "ControlCenter" && ports.contains(where: { $0 == 5000 || $0 == 7000 }) {
          return match("airplay", .system, "AirPlay Receiver (macOS)", stoppable: false)
        }
      case .other:
        if path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/")
          || path.hasPrefix("/usr/sbin/")
        {
          return match(nil, .system, executable, stoppable: false)
        }
        if path.contains(".app/Contents/") {
          return match(nil, .hidden(.otherApp), enclosingApp ?? executable)
        }
      case .fallback: return match(executable, .app)
      }
    }
    return match(executable, .app)
  }
  private static func match(
    _ tool: String?, _ section: Section, _ title: String? = nil, stoppable: Bool = true
  ) -> ToolMatch { ToolMatch(tool: tool, section: section, title: title, stoppable: stoppable) }
  private static func outermostApp(_ path: String) -> String? {
    path.components(separatedBy: "/").filter { $0.hasSuffix(".app") }.first.map {
      String($0.dropLast(4))
    }
  }
  private static func outerApp(_ path: String) -> String? {
    guard let range = path.range(of: ".app/Contents/") else { return nil }
    let prefix = String(path[..<range.lowerBound])
    let components = prefix.split(separator: "/")
    if let appComponent = components.last(where: { $0.hasSuffix(".app") }) {
      return String(appComponent.dropLast(4))
    }
    return URL(fileURLWithPath: prefix).lastPathComponent.replacingOccurrences(of: ".app", with: "")
  }
}
