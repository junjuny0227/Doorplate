import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "P"

        let menu = NSMenu()
        for item in MenuSpike.items(target: self) {
            menu.addItem(item)
        }
        for item in UpdaterSpike.items() {
            menu.addItem(item)
        }
        for item in LoginItemSpike.items() {
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        UpdaterSpike.start()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
