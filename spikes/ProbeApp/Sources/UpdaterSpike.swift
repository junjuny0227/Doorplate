import AppKit
import Sparkle

@MainActor
enum UpdaterSpike {
    // NSMenuItem targets are not retained; keep both the action target and updater alive.
    private static let actions = Actions()
    private static var controller: SPUStandardUpdaterController?

    static func items() -> [NSMenuItem] {
        let check = NSMenuItem(
            title: "Check for Updates…", action: #selector(Actions.checkForUpdates(_:)), keyEquivalent: ""
        )
        check.target = actions

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let info = NSMenuItem(title: "Version \(version) · \(Bundle.main.bundlePath)", action: nil, keyEquivalent: "")
        info.isEnabled = false

        let read = NSMenuItem(
            title: "Read ~/Documents file", action: #selector(Actions.readDocumentsFile(_:)), keyEquivalent: ""
        )
        read.target = actions
        return [.separator(), check, info, read]
    }

    static func start() {
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    @MainActor
    private final class Actions: NSObject {
        @objc func checkForUpdates(_ sender: NSMenuItem) {
            controller?.checkForUpdates(sender)
        }

        @objc func readDocumentsFile(_ sender: NSMenuItem) {
            sender.isEnabled = false
            sender.title = "Read ~/Documents file: reading…"
            let file = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/doorplate-tcc-check/package.json")
            Task { @MainActor in
                let result = await Task.detached(priority: .userInitiated) {
                    do {
                        _ = try Data(contentsOf: file)
                        return "read"
                    } catch {
                        return "denied"
                    }
                }.value
                sender.title = "Read ~/Documents file: \(result)"
                sender.isEnabled = true
            }
        }
    }
}
