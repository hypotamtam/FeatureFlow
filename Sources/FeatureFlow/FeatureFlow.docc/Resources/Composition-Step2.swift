import Foundation
import FeatureFlow

let appFlow = Flow<AppState, AppAction> {
    
    // 1. App-level logic
    Flow { state, action in
        switch action {
        case .showEditor:
            return .result(state.with { $0.editor = EditProfileState(draftName: "User") })
        case .dismissEditor:
            return .result(state.with { $0.editor = nil })
        default:
            return .result(state)
        }
    }
    
    // 2. Composing persistent state using Pullback
    counterFlow.pullback(
        state: \.counter,
        action: AppAction.Cases.counterAction
    )
}
