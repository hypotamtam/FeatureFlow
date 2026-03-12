import Foundation

public struct Flow<Action: FeatureFlow.Action> {
    public struct Result {
        let state: Action.State
        let effects: [Effect<Action>]
        
        init(state: Action.State, effects: [Effect<Action>]) {
            self.state = state
            self.effects = effects
        }
    }
    
    public let run: (Action.State, Action) -> Result
    
    public init(run: @escaping (Action.State, Action) -> Result) {
        self.run = run
    }
}

extension Flow.Result {
    public static func result(_ state: Action.State) -> Self {
        .init(state: state, effects: [])
    }

    public static func result(_ state: Action.State, effect: Effect<Action>?) -> Self {
        .init(state: state, effects: effect.map { [$0] } ?? [])
    }
    
    static func result(_ state: Action.State, effects: [Effect<Action>]) -> Self {
        .init(state: state, effects: effects)
    }
}

public extension Flow {
    func pullback<ParentAction: FeatureFlow.Action>(
        childPath: WritableKeyPath<ParentAction.State, Action.State>,
        toChildAction: @escaping (ParentAction) -> Action?,
        toParentAction: @escaping (Action) -> ParentAction
    ) -> Flow<ParentAction> {
        Flow<ParentAction> { parentState, parentAction in
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

    static func combine(_ flows: Flow<Action>...) -> Self {
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
