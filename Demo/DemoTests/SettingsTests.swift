import Testing
@testable import FeatureFlow
@testable import Demo

@Suite("Settings Domain Tests")
struct SettingsTests {
    
    @MainActor
    @Test("Toggling dark mode should flip the isDarkMode boolean")
    func toggleDarkMode() {
        let initialState = SettingsState(isDarkMode: false)
        let state = settingsFlow.run(initialState, .toggleDarkMode).state
        #expect(state.isDarkMode == true)
        
        let secondState = settingsFlow.run(state, .toggleDarkMode).state
        #expect(secondState.isDarkMode == false)
    }

    @MainActor
    @Test("Toggling notifications should flip the notificationsEnabled boolean")
    func toggleNotifications() {
        let initialState = SettingsState(notificationsEnabled: true)
        let state = settingsFlow.run(initialState, .toggleNotifications).state
        #expect(state.notificationsEnabled == false)
        
        let secondState = settingsFlow.run(state, .toggleNotifications).state
        #expect(secondState.notificationsEnabled == true)
    }
}
