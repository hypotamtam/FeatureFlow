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

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
func createAppFlow(clock: any Clock<Duration>) -> Flow<AppState, AppAction> {
    Flow<AppState, AppAction> { state, action in
        switch action {
        case .updateTitle(let updateTitle):
            let newTitle = updateTitle.trimmingCharacters(in: .whitespaces)
            guard newTitle != state.appTitle else {
                return .result(state)
            }
            return .result(
                state.with { $0.appTitle = newTitle },
                effect: .debounce(id: "sync-title", for: .seconds(1), clock: clock) {
                    return .syncTitle
                }
            )
            
        case .syncTitle:
            return .result(
                state.with { $0.isSyncing = true },
                effect: Effect(id: "sync-title") {
                    try? await clock.sleep(for: .seconds(4))
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
                    try? await clock.sleep(for: .seconds(3))
                    print("Settings saved!")
                    return nil
                }
            )
            
        case .userAction, .counterAction, .settingsAction:
            return .result(state)
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
func createRootFlow(clock: any Clock<Duration> = ContinuousClock()) -> Flow<AppState, AppAction> {
    Flow<AppState, AppAction>.combine(
        userFlow.pullback(
            childPath: \.user,
            toChildAction: { 
                if case .userAction(let action) = $0 { return action }
                return nil 
            },
            toParentAction: { .userAction($0) }
        ),
        
        createCounterFlow(clock: clock).pullback(
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
        
        createAppFlow(clock: clock),
        
        createLogFlow()
    )
}

// Keep a default instance for the Demo UI to use directly
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
let rootFlow = createRootFlow(clock: ContinuousClock())

