import AppKit

enum UpdaterSpike {
    @MainActor
    static func items() -> [NSMenuItem] { [] }

    @MainActor
    static func start() {}
}
