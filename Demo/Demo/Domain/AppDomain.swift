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

@CasePathable
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
                // EDUCATIONAL: .debounce ensures we wait 1 second after the user stops typing
                // before firing the .syncTitle action. If they type again, the timer resets.
                effect: .debounce(id: "sync-title", for: .seconds(1), clock: clock) {
                    return .syncTitle
                }
            )
            
        case .syncTitle:
            return .result(
                state.with { $0.isSyncing = true },
                // EDUCATIONAL: An effect with the same ID ("sync-title") automatically cancels 
                // any previously running effect with that ID, ensuring only the latest sync runs.
                effect: Effect(id: "sync-title") {
                    try? await clock.sleep(for: .seconds(4))
                    return .cancelSync
                }
            )
            
        case .cancelSync:
            return .result(
                state.with { $0.isSyncing = false },
                // EDUCATIONAL: .cancel immediately halts any executing Task with the given ID.
                effect: .cancel(id: "sync-title")
            )
            
        case .saveSettings:
            return .result(
                state,
                // EDUCATIONAL: .throttle ignores any new requests with this ID while the
                // current one is still running. Perfect for preventing double-taps.
                effect: .throttle(id: "save-settings") {
                    print("Saving settings to disk...")
                    try? await clock.sleep(for: .seconds(3))
                    print("Settings saved!")
                    return nil // Fire-and-forget: returns no action
                }
            )
            
        case .userAction, .counterAction, .settingsAction:
            return .result(state)
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
func createRootFlow(clock: any Clock<Duration> = ContinuousClock()) -> Flow<AppState, AppAction> {
    // EDUCATIONAL: .combine merges multiple smaller flows into one large flow.
    // Actions will be passed through them sequentially.
    Flow<AppState, AppAction> {
        // EDUCATIONAL: .pullback transforms a child flow (UserFlow) so it can 
        // operate inside the parent domain (AppDomain).
        // By using @CasePathable on AppAction, we can use AppAction.Cases.userAction
        // instead of manual extraction/embedding closures.
        userFlow.pullback(
            state: \.user,
            action: AppAction.Cases.userAction
        )
        
        createCounterFlow(clock: clock).pullback(
            state: \.counter,
            action: AppAction.Cases.counterAction
        )
        
        settingsFlow.pullback(
            state: \.settings,
            action: AppAction.Cases.settingsAction
        )
        
        createAppFlow(clock: clock)
        
        createLogFlow()
        
    }
}

func createAppFlowLegacy() -> Flow<AppState, AppAction> {
    Flow<AppState, AppAction> { state, action in
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
                effect: .throttle(id: "save-settings", for: 3.0) {
                    print("Saving settings to disk...")
                    return nil
                }
            )
            
        case .userAction, .counterAction, .settingsAction:
            return .result(state)
        }
    }
}

func createRootFlowLegacy() -> Flow<AppState, AppAction> {
    Flow<AppState, AppAction> {
        userFlow.pullback(
            state: \.user,
            action: AppAction.Cases.userAction
        )
        
        counterFlowLegacy.pullback(
            state: \.counter,
            action: AppAction.Cases.counterAction
        )
        
        settingsFlow.pullback(
            state: \.settings,
            action: AppAction.Cases.settingsAction
        )
        
        createAppFlowLegacy()
        
        createLogFlow()
    }
}

let rootFlowLegacy = createRootFlowLegacy()

// Keep a default instance for the Demo UI to use directly
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
let rootFlow = createRootFlow(clock: ContinuousClock())

