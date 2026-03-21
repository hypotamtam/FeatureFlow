import Foundation
import FeatureFlow

struct SettingsState: State, Equatable {
    var isDarkMode = false
    var notificationsEnabled = true
}

enum SettingsAction: Action, Equatable {
    case toggleDarkMode
    case toggleNotifications
}

let settingsFlow = Flow<SettingsState, SettingsAction> { state, action in
    switch action {
    case .toggleDarkMode:
        return .result(state.with { $0.isDarkMode.toggle() })
    case .toggleNotifications:
        return .result(state.with { $0.notificationsEnabled.toggle() })
    }
}
