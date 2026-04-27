import Foundation
import FeatureFlow

@CasePathable
enum EditProfileAction: Action, Equatable {
    case updateName(String)
    case saveTapped
    case saveSuccess(String)
    case saveFailure(String)
}

nonisolated let editProfileFlow = Flow<EditProfileState, EditProfileAction> { state, action in
    switch action {
    case .updateName(let name):
        return .result(state.with { $0.draftName = name })
        
    case .saveTapped:
        let draftName = state.draftName
        return .result(
            state.with { $0.isSaving = true },
            effect: Effect(id: UserEffectId.saveProfile) {
                // Simulate network latency
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // In a real app, we'd call a service here.
                // For the demo, we just return success with the draft name.
                return .saveSuccess(draftName)
            }
        )
        
    case .saveSuccess:
        return .result(state.with { $0.isSaving = false })
        
    case .saveFailure:
        return .result(state.with { $0.isSaving = false })
    }
}
