import SwiftUI
import FeatureFlow

struct SettingsView: View {
    @ObservedObject var store: Store<SettingsAction>
    
    var body: some View {
        Section("Preferences") {
            Toggle("Dark Mode", isOn: Binding(
                get: { store.state.isDarkMode },
                set: { _ in store.send(.toggleDarkMode) }
            ))
            
            Toggle("Notifications", isOn: Binding(
                get: { store.state.notificationsEnabled },
                set: { _ in store.send(.toggleNotifications) }
            ))
        }
    }
}
