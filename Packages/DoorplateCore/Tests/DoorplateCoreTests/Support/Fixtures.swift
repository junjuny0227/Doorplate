import DoorplateCore
import Foundation

// Resolve relative to this source, independent of the test runner's working directory.
enum Fixtures {
  static func url(_ relative: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures", isDirectory: true)
      .appendingPathComponent(relative)
  }

  static func scenario(_ name: String) throws -> ScanFixture {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(
      ScanFixture.self, from: Data(contentsOf: url("scenarios/\(name).json")))
  }
}
