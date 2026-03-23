#if canImport(Observation)
import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct ModernSettingsView: View {
    let store: ObservableViewStore<SettingsState, SettingsAction>
    
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
#endif
