#if canImport(Observation)
import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct ModernSettingsView: View {
    let store: ObservableViewStore<SettingsState, SettingsAction>
    
    var body: some View {
        Section("Preferences") {
            Toggle("Dark Mode", isOn: store.binding(\.isDarkMode, to: .toggleDarkMode))
            
            Toggle("Notifications", isOn: store.binding(\.notificationsEnabled, to: .toggleNotifications))
        }
    }
}
#endif
