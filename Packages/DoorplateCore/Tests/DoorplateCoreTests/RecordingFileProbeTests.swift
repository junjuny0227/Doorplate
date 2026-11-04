import DoorplateCore
import Testing

struct RecordingFileProbeTests {
  @Test func recordsReadsAndExistingPaths() {
    let files = RecordingFileProbe(
      wrapping: FakeFileProbe(
        files: ["/a/package.json": "<내용>", "/a/.git": ""], denied: ["/d"]))
    #expect(files.homeDirectory == "/Users/dev")
    #expect(files.read("/a/package.json") == "<내용>")
    #expect(files.presence("/a/.git") == .present)
    #expect(files.presence("/b") == .absent)
    #expect(files.presence("/d/x") == .denied)
    #expect(files.recorded == ["/a/package.json": "<내용>", "/a/.git": ""])
    #expect(files.denied == ["/d/x"])
  }
}
