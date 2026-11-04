// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DoorplateCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "DoorplateCore", targets: ["DoorplateCore"]),
    .executable(name: "doorplate-scan", targets: ["doorplate-scan"]),
  ],
  targets: [
    .target(name: "DoorplateCore"),
    .executableTarget(name: "doorplate-scan", dependencies: ["DoorplateCore"]),
    .testTarget(name: "DoorplateCoreTests", dependencies: ["DoorplateCore"]),
  ]
)
