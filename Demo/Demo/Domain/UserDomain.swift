import Foundation
import FeatureFlow

struct UserState: State {
    var name = "Unknown User"
    var isLoading = false
    var error: String? = nil
}

enum UserAction: Action, Equatable {
    typealias State = UserState
    
    case fetchRequest
    case fetchSuccess(String)
    case fetchFailure(String)
}

let userFlow = Flow<UserAction> { state, action in
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
    }
}
