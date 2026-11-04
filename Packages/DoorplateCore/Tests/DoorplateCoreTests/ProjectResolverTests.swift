import Foundation
import Testing

@testable import DoorplateCore

struct ProjectResolverTests {
  @Test func nearestPackageName() {
    let root = "/Users/dev/repot"
    let files = FakeFileProbe(files: [
      "\(root)/apps/site/package.json": "{\"name\":\"@repot/site\"}",
      "\(root)/package.json": "{\"name\":\"repot\"}", "\(root)/.git": "",
    ])
    #expect(
      ProjectResolver(files: files).resolve(startingAt: "\(root)/apps/site")
        == ProjectInfo(name: "@repot/site", directory: "\(root)/apps/site", repositoryRoot: root))
  }
  @Test func packageWithoutNameFallsThrough() {
    let files = FakeFileProbe(files: [
      "/Users/dev/repot/package.json": "{\"private\":true}", "/Users/dev/repot/.git": "",
    ])
    #expect(ProjectResolver(files: files).resolve(startingAt: "/Users/dev/repot")?.name == "repot")
  }
  @Test func cargoWorkspaceRootIsSkipped() {
    let root = "/Users/dev/repo"
    let files = FakeFileProbe(files: [
      "\(root)/Cargo.toml": "[workspace]\nmembers = [\"api\"]", "\(root)/.git": "",
      "\(root)/api/Cargo.toml": "[package]\nname = \"api\"",
    ])
    let r = ProjectResolver(files: files)
    #expect(r.resolve(startingAt: root)?.name == "repo")
    #expect(r.resolve(startingAt: "\(root)/api")?.name == "api")
  }
  @Test func pyprojectProjectName() {
    let files = FakeFileProbe(files: [
      "/Users/dev/shop/pyproject.toml": "[project]\nname = \"shop-api\""
    ])
    #expect(
      ProjectResolver(files: files).resolve(startingAt: "/Users/dev/shop")?.name == "shop-api")
    let poetry = FakeFileProbe(files: [
      "/Users/dev/x/pyproject.toml": "[tool.poetry]\nname = \"x\"", "/Users/dev/x/.git": "",
    ])
    #expect(ProjectResolver(files: poetry).resolve(startingAt: "/Users/dev/x")?.name == "x")
  }
  @Test func settingsGradleKtsAndGroovy() {
    for (file, value) in [("settings.gradle.kts", "\"shop\""), ("settings.gradle", "'shop'")] {
      let f = FakeFileProbe(files: ["/Users/dev/shop/\(file)": "rootProject.name = \(value)"])
      #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev/shop")?.name == "shop")
    }
  }
  @Test func gradleSubmoduleUsesRootName() {
    let f = FakeFileProbe(files: [
      "/Users/dev/shop/settings.gradle.kts": "rootProject.name = \"shop\"",
      "/Users/dev/shop/api/build.gradle.kts": "",
    ])
    #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev/shop/api")?.name == "shop")
  }
  @Test func pomArtifactIgnoresParent() {
    let xml =
      "<project><parent><artifactId>spring-boot-starter-parent</artifactId></parent><artifactId>shop-api</artifactId></project>"
    let f = FakeFileProbe(files: ["/Users/dev/shop/pom.xml": xml])
    #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev/shop")?.name == "shop-api")
  }
  @Test func goModLastSegment() {
    let f = FakeFileProbe(files: ["/Users/dev/billing/go.mod": "module github.com/acme/billing"])
    #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev/billing")?.name == "billing")
  }
  @Test func stopsBeforeHome() {
    let f = FakeFileProbe(files: ["/Users/dev/package.json": "{\"name\":\"oops\"}"])
    #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev/scratch") == nil)
  }
  @Test func homeOrRootStartIsNil() {
    let f = FakeFileProbe()
    #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev") == nil)
    #expect(ProjectResolver(files: f).resolve(startingAt: "/") == nil)
  }
  @Test func malformedPackageJSONFallsThrough() {
    let f = FakeFileProbe(files: ["/Users/dev/repo/package.json": "{", "/Users/dev/repo/.git": ""])
    #expect(ProjectResolver(files: f).resolve(startingAt: "/Users/dev/repo")?.name == "repo")
  }
  @Test func deniedFallsBackToFolderName() {
    let f = FakeFileProbe(denied: ["/Users/dev/Documents"])
    #expect(
      ProjectResolver(files: f).resolve(startingAt: "/Users/dev/Documents/Repot/apps/desktop")
        == ProjectInfo(
          name: "desktop", directory: "/Users/dev/Documents/Repot/apps/desktop", repositoryRoot: nil
        ))
  }
  @Test func startDirectoryForJar() {
    #expect(
      ProjectResolver.startDirectory(
        for: ProcessRecord(
          pid: 1, name: "java", arguments: ["java", "-jar", "build/libs/app.jar"],
          cwd: "/Users/dev/shop")) == "/Users/dev/shop/build/libs")
    #expect(
      ProjectResolver.startDirectory(
        for: ProcessRecord(pid: 1, name: "java", arguments: ["java", "-jar", "/opt/app/app.jar"]))
        == "/opt/app")
    #expect(
      ProjectResolver.startDirectory(
        for: ProcessRecord(pid: 1, name: "java", arguments: ["java", "-jar", "app.jar"])) == nil)
  }
}
