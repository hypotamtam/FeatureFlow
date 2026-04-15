import FeatureFlow

func createLogFlow<State: FeatureFlow.State, Action: Sendable>() -> Flow<State, Action> {
    .init { state, action in
        print("---- Send ----")
        dump(action, name: "Action")
        dump(state, name: "State")
        print("--------------")
        return .result(state)
    }
}
