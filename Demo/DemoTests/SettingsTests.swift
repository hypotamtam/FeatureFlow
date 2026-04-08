import Testing
import FeatureFlow
import FeatureFlowTesting
@testable import Demo

@Suite("Settings Domain Tests")
struct SettingsTests {
    
    @MainActor
    @Test("Toggling dark mode should flip the isDarkMode boolean")
    func toggleDarkMode() async {
        let store = TestStore(initialState: SettingsState(isDarkMode: false), flow: settingsFlow)
        
        await store.send(.toggleDarkMode) {
            $0.isDarkMode = true
        }
        
        await store.send(.toggleDarkMode) {
            $0.isDarkMode = false
        }
    }

    @MainActor
    @Test("Toggling notifications should flip the notificationsEnabled boolean")
    func toggleNotifications() async {
        let store = TestStore(initialState: SettingsState(notificationsEnabled: true), flow: settingsFlow)
        
        await store.send(.toggleNotifications) {
            $0.notificationsEnabled = false
        }
        
        await store.send(.toggleNotifications) {
            $0.notificationsEnabled = true
        }
    }
}
