import DoorplateCore
import Foundation
import Testing

@Suite struct ScenarioTests {
  static let names = [
    "node-monorepo-vite", "next-dev", "spring-gradle", "spring-maven",
    "java-jar-outside-project", "cargo-run", "python-django-uvicorn", "rails-puma",
    "docker-compose", "macos-noise", "gunicorn-prefork", "documents-denied", "adb-server",
    "macos-system-visible",
  ]

  @Test(arguments: names)
  func snapshotMatchesGolden(name: String) async throws {
    let scenarioNames = try FileManager.default.contentsOfDirectory(
      at: Fixtures.url("scenarios"), includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" }
    .map { $0.deletingPathExtension().lastPathComponent }
    #expect(scenarioNames.sorted() == Self.names.sorted())
    let fixture = try Fixtures.scenario(name)
    let dockerResult: Result<[Container], DockerError>
    switch fixture.docker.status {
    case .ok: dockerResult = .success(fixture.docker.containers ?? [])
    case .absent: dockerResult = .failure(.absent)
    case .notResponding: dockerResult = .failure(.notResponding)
    }
    let files = FakeFileProbe(home: fixture.home, files: fixture.files, denied: fixture.denied)
    let scanner = Scanner(
      processes: FakeProcessSource(listeners: fixture.listeners, processes: fixture.processes),
      files: files,
      docker: FakeDockerSource(result: dockerResult), currentUID: fixture.currentUID,
      now: { fixture.now }, fixtureLookup: ProjectResolver(files: files))
    let outcome = try #require(await scanner.scan(settings: fixture.settings))
    #expect(outcome.failedAt == nil)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let actual = try encoder.encode(outcome.snapshot)
    let expectedURL = Fixtures.url("expected/\(name).json")
    if ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1" {
      try actual.write(to: expectedURL, options: .atomic)
    } else {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let expected = try decoder.decode(Snapshot.self, from: Data(contentsOf: expectedURL))
      #expect(outcome.snapshot == expected, "Golden mismatch: \(name)")
    }
  }
}
