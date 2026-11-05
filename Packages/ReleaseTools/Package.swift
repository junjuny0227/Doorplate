// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ReleaseTools",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "AppcastKit", targets: ["AppcastKit"]),
    .executable(name: "appcast", targets: ["appcast"]),
  ],
  targets: [
    .target(name: "AppcastKit"),
    .executableTarget(name: "appcast", dependencies: ["AppcastKit"]),
    .testTarget(name: "AppcastKitTests", dependencies: ["AppcastKit"]),
  ]
)
