import Foundation

public struct Flow<State: FeatureFlow.State, Action: Sendable>: Sendable {
    public struct Result: Sendable {
        package let state: State
        package let effects: [Effect<Action>]
        
        init(state: State, effects: [Effect<Action>]) {
            self.state = state
            self.effects = effects
        }
    }
    
    public let run: @Sendable (State, Action) -> Result
    
    public init(run: @escaping @Sendable (State, Action) -> Result) {
        self.run = run
    }
}

extension Flow.Result {
    public static func result(_ state: State) -> Self {
        .init(state: state, effects: [])
    }

    public static func result(_ state: State, effect: Effect<Action>?) -> Self {
        .init(state: state, effects: effect.map { [$0] } ?? [])
    }
    
    static func result(_ state: State, effects: [Effect<Action>]) -> Self {
        .init(state: state, effects: effects)
    }
}

public extension Flow {
    func pullback<ParentState: FeatureFlow.State, ParentAction: Sendable>(
        childPath: WritableKeyPath<ParentState, State> & Sendable,
        toChildAction: @escaping @Sendable (ParentAction) -> Action?,
        toParentAction: @escaping @Sendable (Action) -> ParentAction
    ) -> Flow<ParentState, ParentAction> {
        Flow<ParentState, ParentAction> { parentState, parentAction in
            guard let childAction = toChildAction(parentAction) else {
                return .result(parentState)
            }

            let result = self.run(parentState[keyPath: childPath], childAction)

            var newParentState = parentState
            newParentState[keyPath: childPath] = result.state

            return .result(
                newParentState,
                effects: result.effects.map { $0.map(transform: toParentAction) }
            )
        }
    }

    static func combine(_ flows: Flow<State, Action>...) -> Self {
        Flow { state, action in
            var currentState = state
            var allEffects: [Effect<Action>] = []

            for flow in flows {
                let result = flow.run(currentState, action)
                currentState = result.state
                allEffects.append(contentsOf: result.effects)
            }

            return .result(currentState, effects: allEffects)
        }
    }
}
