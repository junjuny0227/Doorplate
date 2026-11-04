import AppKit
import DoorplateMenu
import SwiftUI

@MainActor struct SettingsView: View {
  @ObservedObject var settings: SettingsStore
  @ObservedObject var loginItem: LoginItem
  let onChange: () -> Void
  @State private var terminals: [TerminalApp] = []

  var body: some View {
    Form {
      Toggle(
        L10n.text(.settingsOpenAtLogin),
        isOn: Binding(
          get: { loginItem.isEnabled },
          set: {
            loginItem.setEnabled($0)
            onChange()
          }))
      if loginItem.requiresApproval {
        Text(L10n.text(.settingsLoginRequiresApproval))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Stepper(value: $settings.longRunningHours, in: 1...168) {
        Text(L10n.text(.settingsLongRunning))
        Text(L10n.format(.settingsHours, settings.longRunningHours))
      }
      Toggle(L10n.text(.settingsShowDevTools), isOn: $settings.showDevTools)
      Toggle(L10n.text(.settingsShowOtherApps), isOn: $settings.showOtherApps)
      Picker(L10n.text(.settingsTerminal), selection: terminalSelection) {
        ForEach(terminals, id: \.bundleID) { app in
          Text(verbatim: app.name).tag(app.bundleID)
        }
      }
      Toggle(L10n.text(.settingsAutoUpdate), isOn: $settings.checkForUpdates)
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear { refreshSystemState() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in refreshSystemState()
    }
    .onChange(of: settings.longRunningHours) { onChange() }
    .onChange(of: settings.showDevTools) { onChange() }
    .onChange(of: settings.showOtherApps) { onChange() }
    .onChange(of: settings.terminalBundleID) { onChange() }
    .onChange(of: settings.checkForUpdates) { onChange() }
  }

  private var terminalSelection: Binding<String> {
    Binding(
      get: {
        terminals.contains { $0.bundleID == settings.terminalBundleID }
          ? settings.terminalBundleID : "com.apple.Terminal"
      },
      set: { settings.terminalBundleID = $0 })
  }

  private func refreshSystemState() {
    loginItem.refresh()
    terminals = TerminalApps.installed {
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
    }
  }
}
