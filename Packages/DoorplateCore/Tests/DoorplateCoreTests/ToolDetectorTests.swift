import Testing

@testable import DoorplateCore

private func proc(_ name: String, path: String, args: [String]) -> ProcessRecord {
  ProcessRecord(pid: 1, name: name, executablePath: path, arguments: args)
}
private func detect(_ p: ProcessRecord, parent: ProcessRecord? = nil, ports: [UInt16] = [])
  -> ToolMatch
{
  ToolDetector.detect(p, parent: parent, ports: ports)
}
@Test func viteFromNodeModulesBin() {
  #expect(
    detect(proc("node", path: "/bin/node", args: ["node", "/r/node_modules/.bin/vite"]))
      == ToolMatch(tool: "vite", section: .app, title: nil))
}
@Test func viteFromPackageDir() {
  #expect(
    detect(proc("node", path: "/bin/node", args: ["node", "/r/node_modules/vite/bin/vite.js"]))
      == ToolMatch(tool: "vite", section: .app, title: nil))
}
@Test func nextServerChild() {
  #expect(
    detect(proc("next-server (v1", path: "/x", args: ["next-server (v15.0.0)"])).tool == "next")
}
@Test func plainNode() {
  #expect(detect(proc("node", path: "/bin/node", args: ["node", "server.js"])).tool == "node")
}
@Test func gradleDaemonHidden() {
  #expect(
    detect(
      proc(
        "java", path: "/bin/java",
        args: ["java", "org.gradle.launcher.daemon.bootstrap.GradleDaemon"])
    ).tool == "gradle daemon")
}
@Test func kotlinDaemonHidden() {
  #expect(
    detect(
      proc(
        "java", path: "/bin/java",
        args: ["java", "org.jetbrains.kotlin.daemon.KotlinCompileDaemon"])
    ).tool == "kotlin daemon")
}
@Test func adbServerHidden() {
  #expect(
    detect(
      proc(
        "adb", path: "/Users/dev/Library/Android/sdk/platform-tools/adb",
        args: ["adb", "-L", "tcp:5037", "fork-server", "server", "--reply-fd", "4"]),
      ports: [5037]) == ToolMatch(tool: "adb", section: .hidden(.devTool), title: "adb"))
}
@Test func adbWithoutArgumentsHidden() {
  #expect(
    detect(ProcessRecord(pid: 1, name: "adb"), ports: [5037])
      == ToolMatch(tool: "adb", section: .hidden(.devTool), title: "adb"))
}
@Test func adbLookalikeIsNotDeveloperTool() {
  #expect(
    detect(
      proc("adb-helper", path: "/Users/dev/bin/adb-helper", args: ["adb-helper"]), ports: [5037])
      == ToolMatch(tool: "adb-helper", section: .app, title: nil))
}
@Test func adbArgumentDoesNotHideNodeServer() {
  #expect(
    detect(proc("node", path: "/opt/homebrew/bin/node", args: ["node", "adb"]), ports: [5037])
      == ToolMatch(tool: "node", section: .app, title: nil))
}
@Test func gradleBootRunChild() {
  #expect(
    detect(
      proc("java", path: "/bin/java", args: ["java"]),
      parent: proc("java", path: "/bin/java", args: ["java", "GradleDaemon"])
    ).tool == "gradle")
}
@Test func mavenChild() {
  #expect(
    detect(
      proc("java", path: "/bin/java", args: ["java"]),
      parent: proc(
        "java", path: "/bin/java",
        args: ["java", "org.codehaus.plexus.classworlds.launcher.Launcher"])
    ).tool == "maven")
}
@Test func javaJar() {
  #expect(
    detect(proc("java", path: "/bin/java", args: ["java", "-jar", "app.jar"])).tool == "java")
}
@Test func javaFromIDEBundledRuntimeIsApp() {
  #expect(
    detect(
      proc(
        "java", path: "/Applications/IntelliJ IDEA.app/Contents/jbr/Contents/Home/bin/java",
        args: ["java"])) == ToolMatch(tool: "java", section: .app, title: nil))
}
@Test func cargoParent() {
  #expect(
    detect(
      proc("api", path: "/x/api", args: ["api"]),
      parent: proc("cargo", path: "/bin/cargo", args: ["cargo", "run"])
    ).tool == "cargo")
}
@Test func cargoTargetPath() {
  #expect(detect(proc("api", path: "/x/target/debug/api", args: ["api"])).tool == "cargo")
}
@Test func frameworkPythonName() {
  #expect(
    detect(
      proc(
        "Python",
        path:
          "/Library/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python",
        args: ["python3", "manage.py", "runserver"])
    ).tool == "django")
}
@Test func django() {
  #expect(
    detect(proc("python3", path: "/bin/python3", args: ["python3", "manage.py", "runserver"])).tool
      == "django")
}
@Test func uvicornScript() {
  #expect(
    detect(
      proc("python3", path: "/bin/python3", args: ["/v/bin/python3", "/v/bin/uvicorn", "main:app"])
    ).tool == "uvicorn")
}
@Test func uvicornModule() {
  #expect(
    detect(proc("python3", path: "/bin/python3", args: ["python3", "-m", "uvicorn", "main:app"]))
      .tool == "uvicorn")
}
@Test func flask() {
  #expect(
    detect(proc("python3", path: "/bin/python3", args: ["python3", "-m", "flask"])).tool == "flask")
}
@Test func gunicorn() {
  #expect(
    detect(proc("python3", path: "/bin/python3", args: ["gunicorn", "app:app"])).tool == "gunicorn")
}
@Test func railsPuma() {
  #expect(
    detect(proc("puma 6", path: "/bin/puma", args: ["puma 6.4.0 (tcp://127.0.0.1:3000) [shop]"]))
      .tool == "rails")
}
@Test func intellijItselfHidden() {
  #expect(
    detect(
      proc("idea", path: "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea", args: ["idea"])
    ).section == .hidden(.devTool))
}
@Test func vsCodeHelperHidden() {
  #expect(
    detect(
      proc(
        "Code Helper",
        path:
          "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper",
        args: ["helper"])
    ).title == "Visual Studio Code")
}
@Test func airPlayIsSystem() {
  #expect(
    detect(
      proc(
        "ControlCenter", path: "/System/Library/CoreServices/ControlCenter", args: ["ControlCenter"]
      ), ports: [5000, 7000])
      == ToolMatch(tool: "airplay", section: .system, title: "AirPlay Receiver (macOS)"))
}
@Test func controlCenterOtherPortIsHidden() {
  #expect(
    detect(
      proc(
        "ControlCenter", path: "/System/Library/CoreServices/ControlCenter", args: ["ControlCenter"]
      ), ports: [49152]
    ).section == .hidden(.otherApp))
}
@Test func otherAppHidden() {
  let match = detect(
    proc("Spotify", path: "/Applications/Spotify.app/Contents/MacOS/Spotify", args: ["Spotify"]))
  #expect(match.title == "Spotify")
  #expect(match.stoppable)
}
@Test func macOSServiceIsHidden() {
  let match = detect(proc("rapportd", path: "/usr/libexec/rapportd", args: ["rapportd"]))
  #expect(match.title == "rapportd")
  #expect(!match.stoppable)
}
@Test func unknownBinaryIsApp() {
  #expect(detect(proc("caddy", path: "/opt/homebrew/bin/caddy", args: ["caddy"])).tool == "caddy")
}
@Test func dockerDesktopBackendIsRuntime() {
  #expect(
    detect(
      proc(
        "backend", path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend",
        args: ["backend"])
    )
      == ToolMatch(
        tool: "container runtime", section: .hidden(.otherApp), title: "Docker", stoppable: false))
}
@Test func orbStackHelperIsRuntime() {
  #expect(
    detect(
      proc(
        "helper",
        path:
          "/Applications/OrbStack.app/Contents/Frameworks/OrbStack Helper.app/Contents/MacOS/OrbStack Helper",
        args: ["helper"])
    ).title == "OrbStack")
}
@Test func colimaProcessesAreRuntime() {
  for n in ["limactl", "qemu-system-aarch64", "vfkit"] {
    #expect(detect(proc(n, path: "/opt/homebrew/bin/\(n)", args: [n])).tool == "container runtime")
  }
}
@Test func plainPython() {
  #expect(
    detect(proc("python3", path: "/bin/python3", args: ["python3", "-m", "http.server"])).tool
      == "python")
}
@Test func plainRuby() {
  #expect(detect(proc("ruby", path: "/bin/ruby", args: ["ruby", "script.rb"])).tool == "ruby")
}
@Test func nonCargoBinaryIsNotCargo() {
  #expect(
    detect(
      proc("api", path: "/Users/dev/bin/api", args: ["api"]),
      parent: proc("zsh", path: "/bin/zsh", args: ["zsh"])
    ).tool == "api")
}
