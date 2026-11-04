// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DoorplateMenu",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  products: [.library(name: "DoorplateMenu", targets: ["DoorplateMenu"])],
  dependencies: [.package(path: "../DoorplateCore")],
  targets: [
    .target(
      name: "DoorplateMenu", dependencies: ["DoorplateCore"],
      resources: [.process("Resources")]),
    .testTarget(name: "DoorplateMenuTests", dependencies: ["DoorplateMenu", "DoorplateCore"]),
  ]
)
