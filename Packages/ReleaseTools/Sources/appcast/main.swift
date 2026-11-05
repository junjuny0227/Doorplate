import AppcastKit
import Foundation

private enum CommandError: Error, CustomStringConvertible {
  case usage

  var description: String {
    "Usage: appcast add --file <path> --version <version> --build <build> --url <url> --sign-output <output>"
  }
}

private func add(arguments: [String]) throws {
  let required: Set<String> = ["--file", "--version", "--build", "--url", "--sign-output"]
  guard arguments.first == "add", arguments.count == 11 else { throw CommandError.usage }
  var options: [String: String] = [:]
  for index in stride(from: 1, to: arguments.count, by: 2) {
    let key = arguments[index]
    let value = arguments[index + 1]
    guard required.contains(key), options[key] == nil, !value.isEmpty else {
      throw CommandError.usage
    }
    options[key] = value
  }
  guard let path = options["--file"], let version = options["--version"],
    let build = options["--build"], let urlString = options["--url"],
    let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
    url.host != nil, let signOutput = options["--sign-output"]
  else { throw CommandError.usage }
  let signature = try Appcast.parseSignOutput(signOutput)
  let file = URL(fileURLWithPath: path)
  let xml: String
  if FileManager.default.fileExists(atPath: file.path) {
    xml = try String(contentsOf: file, encoding: .utf8)
  } else {
    xml = Appcast.empty(
      title: "Doorplate", link: URL(string: "https://github.com/junjuny0227/Doorplate")!)
  }
  let item = AppcastItem(
    version: version, build: build, url: url, length: signature.length,
    edSignature: signature.edSignature, publishedAt: Date())
  try Appcast.adding(item, to: xml).write(to: file, atomically: true, encoding: .utf8)
}

do {
  try add(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
  FileHandle.standardError.write(Data("appcast: \(error)\n".utf8))
  exit(1)
}
