import FeatureFlow
import SwiftUI

struct CounterState: State {
    var count = 0
}

enum CounterAction: Action {
    typealias State = CounterState
    
    case incrementTapped
    case decrementTapped
}

let counterFlow = Flow<CounterAction> { state, action in
    switch action {
    case .incrementTapped:
        return .result(state.with { $0.count += 1 })
    case .decrementTapped:
        return .result(state.with { $0.count -= 1 })
    }
}

struct CounterView: View {
    @State var viewStore: ObservableViewStore<CounterState, CounterAction>
    
    var body: some View {
        HStack(spacing: 20) {
            Button("-") { viewStore.send(.decrementTapped) }
            Text("\(viewStore.state.count)")
            Button("+") { viewStore.send(.incrementTapped) }
        }
        .font(.largeTitle)
    }
}
