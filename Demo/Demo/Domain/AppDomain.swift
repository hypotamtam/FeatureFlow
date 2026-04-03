import Foundation
import FeatureFlow

struct AppState: State {
    var user = UserState()
    var counter = CounterState()
    var settings = SettingsState()
    var appTitle = "My Modular App"
    var isSyncing = false
    
    var isGlobalLoading: Bool {
        user.isLoading || counter.isProcessing
    }
}

enum AppAction: Action, Equatable {
    case userAction(UserAction)
    case counterAction(CounterAction)
    case settingsAction(SettingsAction)
    
    case updateTitle(String)
    case syncTitle
    case cancelSync
    case saveSettings
}

fileprivate let appFlow = Flow<AppState, AppAction> { state, action in
    switch action {
    case .updateTitle(let updateTitle):
        let newTitle = updateTitle.trimmingCharacters(in: .whitespaces)
        guard newTitle != state.appTitle else {
            return .result(state)
        }
        return .result(
            state.with { $0.appTitle = newTitle },
            effect: .debounce(id: "sync-title", for: 1.0) {
                return .syncTitle
            }
        )
        
    case .syncTitle:
        return .result(
            state.with { $0.isSyncing = true },
            effect: Effect(id: "sync-title") {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                return .cancelSync
            }
        )
        
    case .cancelSync:
        return .result(
            state.with { $0.isSyncing = false },
            effect: .cancel(id: "sync-title")
        )
        
    case .saveSettings:
        return .result(
            state,
            effect: .throttle(id: "save-settings") {
                print("Saving settings to disk...")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                print("Settings saved!")
                return nil
            }
        )
        
    case .userAction, .counterAction, .settingsAction:
        return .result(state)
    }
}

let rootFlow = Flow<AppState, AppAction>.combine(
    userFlow.pullback(
        childPath: \.user,
        toChildAction: { 
            if case .userAction(let action) = $0 { return action }
            return nil 
        },
        toParentAction: { .userAction($0) }
    ),
    
    counterFlow.pullback(
        childPath: \.counter,
        toChildAction: {
            if case .counterAction(let action) = $0 { return action }
            return nil
        },
        toParentAction: { .counterAction($0) }
    ),
    
    settingsFlow.pullback(
        childPath: \.settings,
        toChildAction: {
            if case .settingsAction(let action) = $0 { return action }
            return nil
        },
        toParentAction: { .settingsAction($0) }
    ),
    
    appFlow,
    
    createLogFlow()
)

