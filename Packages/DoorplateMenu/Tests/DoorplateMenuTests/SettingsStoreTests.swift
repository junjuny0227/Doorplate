import DoorplateCore
import Foundation
import Testing

@testable import DoorplateMenu

@MainActor
struct SettingsStoreTests {
  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString)!
  }

  @Test func defaultsMatchSpec() {
    let store = SettingsStore(defaults: makeDefaults())
    #expect(store.longRunningHours == 24)
    #expect(store.showDevTools == false)
    #expect(store.showOtherApps == false)
    #expect(store.terminalBundleID == "com.apple.Terminal")
    #expect(store.checkForUpdates == true)
    #expect(store.snapshotSettings.longRunningThreshold == 86_400)
  }

  @Test func persistsAcrossInstances() {
    let defaults = makeDefaults()
    let first = SettingsStore(defaults: defaults)
    first.longRunningHours = 48
    first.showDevTools = true
    first.showOtherApps = true
    first.terminalBundleID = "com.googlecode.iterm2"
    first.checkForUpdates = false
    let second = SettingsStore(defaults: defaults)
    #expect(second.longRunningHours == 48)
    #expect(second.showDevTools)
    #expect(second.showOtherApps)
    #expect(second.terminalBundleID == "com.googlecode.iterm2")
    #expect(second.checkForUpdates == false)
  }

  @Test func clampsHours() {
    let store = SettingsStore(defaults: makeDefaults())
    store.longRunningHours = 0
    #expect(store.longRunningHours == 1)
    store.longRunningHours = 500
    #expect(store.longRunningHours == 168)
  }
}
