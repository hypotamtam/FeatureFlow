import Foundation
import FeatureFlow

struct SettingsState: State, Equatable {
    var isDarkMode = false
    var notificationsEnabled = true
}

enum SettingsAction: Action, Equatable {
    typealias State = SettingsState
    
    case toggleDarkMode
    case toggleNotifications
}

let settingsFlow = Flow<SettingsAction> { state, action in
    switch action {
    case .toggleDarkMode:
        return .result(state.with { $0.isDarkMode.toggle() })
    case .toggleNotifications:
        return .result(state.with { $0.notificationsEnabled.toggle() })
    }
}
