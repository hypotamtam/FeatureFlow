import FeatureFlow

struct CounterState: State {
    var count = 0
}

enum CounterAction: Action {
    case increment
    case decrement
}

let counterFlow = Flow<CounterAction> { state, action in
    switch action {
    case .incrementTapped:
        return .result(state.with { $0.count += 1 })
    case .decrementTapped:
        return .result(state.with { $0.count -= 1 })
    }
}
