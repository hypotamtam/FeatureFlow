import SwiftUI
import FeatureFlow

struct SettingsView: View {
    @ObservedObject var store: ViewStore<SettingsState, SettingsAction>
    
    var body: some View {
        Section("Preferences") {
            Toggle("Dark Mode", isOn: store.binding(\.isDarkMode, to: .toggleDarkMode))
            
            Toggle("Notifications", isOn: store.binding(\.notificationsEnabled, to: .toggleNotifications))
        }
    }
}
