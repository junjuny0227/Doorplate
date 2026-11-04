import AppKit
import ServiceManagement
import os

@MainActor
enum LoginItemSpike {
    private static let logger = Logger(
        subsystem: "io.github.junjuny0227.doorplate.probe",
        category: "login"
    )
    private static let service = SMAppService.mainApp
    static let menuDelegate = LoginMenuDelegate()
    private static var retainedTarget: LoginItemActionTarget?

    static func items(target: LoginItemActionTarget) -> [NSMenuItem] {
        retainedTarget = target
        let toggle = NSMenuItem(
            title: "Open at Login",
            action: #selector(LoginItemActionTarget.toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        toggle.target = target
        toggle.state = service.status == .enabled ? .on : .off

        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        status.tag = statusItemTag
        return [toggle, status]
    }

    private static let statusItemTag = 6006

    private static var statusTitle: String {
        "Login item status: \(statusText(service.status))"
    }

    private static func statusText(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: "notRegistered"
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notFound: "notFound"
        @unknown default: "unknown"
        }
    }

    fileprivate static func toggle(_ sender: NSMenuItem) {
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            logger.error("Login item toggle failed: \(String(describing: error), privacy: .public)")
            if let menu = sender.menu {
                updateStatusItem(in: menu, message: "Login item error: \(error.localizedDescription)")
            }
        }
        refresh(menu: sender.menu)
    }

    fileprivate static func refresh(menu: NSMenu?) {
        guard let menu else { return }
        let toggle = menu.items.first { $0.title == "Open at Login" }
        toggle?.state = service.status == .enabled ? .on : .off
        updateStatusItem(in: menu)
    }

    private static func updateStatusItem(in menu: NSMenu, message: String? = nil) {
        guard let item = menu.items.first(where: { $0.tag == statusItemTag }) else { return }
        item.title = message ?? statusTitle
    }
}

@MainActor
final class LoginItemActionTarget: NSObject {
    @objc func toggleLoginItem(_ sender: NSMenuItem) {
        LoginItemSpike.toggle(sender)
    }
}

@MainActor
final class LoginMenuDelegate: NSObject, NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        LoginItemSpike.refresh(menu: menu)
    }
}
