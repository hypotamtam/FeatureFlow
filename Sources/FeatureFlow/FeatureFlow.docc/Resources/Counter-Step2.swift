import FeatureFlow

struct CounterState: State {
    var count = 0
}

enum CounterAction: Action {    
    case increment
    case decrement
}
