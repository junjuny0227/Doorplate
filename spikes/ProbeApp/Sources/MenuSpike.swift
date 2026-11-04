import AppKit
import os

@MainActor
enum MenuSpike {
    private static let logger = Logger(
        subsystem: "io.github.junjuny0227.doorplate.probe",
        category: "menu"
    )
    private static let actionTarget = MenuActionTarget()
    private static var titleTimer: Timer?
    private static weak var rowItem: NSMenuItem?
    private static var trailingNumber = 1

    static func items(target: AnyObject) -> [NSMenuItem] {
        _ = target // The supplied AppDelegate has no menu action to handle.

        let row = NSMenuItem(title: "5173  sample", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "5173  sample")
        submenu.addItem(NSMenuItem(title: "Open", action: nil, keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: "Stop", action: nil, keyEquivalent: ""))
        row.submenu = submenu
        rowItem = row

        let alt = NSMenuItem(
            title: "Stop 5173 sample",
            action: #selector(MenuActionTarget.alternateFired(_:)),
            keyEquivalent: ""
        )
        alt.isAlternate = true
        alt.keyEquivalentModifierMask = [.option]
        alt.target = actionTarget

        titleTimer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated {
                trailingNumber += 1
                rowItem?.title = "5173  sample \(trailingNumber)"
            }
        }
        titleTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        return [row, alt]
    }

    fileprivate static func logAlternate() {
        logger.info("alternate fired")
    }
}

@MainActor
private final class MenuActionTarget: NSObject {
    @objc func alternateFired(_ sender: Any?) {
        MenuSpike.logAlternate()
    }
}
