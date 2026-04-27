import Foundation
import FeatureFlow

struct EditProfileState: State {
    var draftName: String
    var isSaving: Bool = false
    
    var isSaveDisabled: Bool {
        isSaving || draftName.isEmpty
    }
}

struct UserState: State {
    var name = "Unknown User"
    var isLoading = false
    var error: String? = nil
    var editProfile: EditProfileState? = nil
}

@CasePathable
enum UserAction: Action, Equatable {
    case fetchRequest
    case fetchSuccess(String)
    case fetchFailure(String)
    
    case showEditor
    case dismissEditor
    case editProfile(EditProfileAction)
}

fileprivate let internalUserFlow = Flow<UserState, UserAction> { state, action in
    switch action {
    case .fetchRequest:
        return .result(
            state.with {
                $0.isLoading = true
                $0.error = nil
            },
            effect: Effect {
                do {
                    let name = try await Current.userService.fetchUser()
                    return .fetchSuccess(name)
                } catch {
                    return .fetchFailure(error.localizedDescription)
                }
            }
        )
    case .fetchSuccess(let name):
        return .result(state.with { $0.isLoading = false; $0.name = name })
    case .fetchFailure(let message):
        return .result(state.with { $0.isLoading = false; $0.error = message })

    case .showEditor:
        return .result(state.with {
            $0.editProfile = EditProfileState(draftName: $0.name)
        })

    case .dismissEditor:
        return .result(state.with { $0.editProfile = nil })

    case .editProfile(.saveSuccess(let newName)):
        // We still need to coordinate the success back to the parent name
        // but the rest is handled by ifLet
        return .result(state.with {
            $0.name = newName
            $0.editProfile = nil
        })

    case .editProfile:
        return .result(state)
    }
}

func createUserFlow() -> Flow<UserState, UserAction> {
    Flow<UserState, UserAction> {
        internalUserFlow
        
        // Use the new ifLet operator!
        editProfileFlow.ifLet(state: \.editProfile, action: UserAction.Cases.editProfile)
    }
}

let userFlow = createUserFlow()
