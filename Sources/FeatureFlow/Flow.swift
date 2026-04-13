import Foundation

/// A pure function that defines the business logic of a feature.
///
/// A `Flow` takes the current `State` and an incoming `Action`, and returns a `Result` 
/// containing the newly mutated state and an array of optional asynchronous `Effect`s to execute.
public struct Flow<State: FeatureFlow.State, Action: Sendable>: Sendable {
    
    /// The result of executing a `Flow`.
    public struct Result: Sendable {
        /// The new, mutated state.
        package let state: State
        /// The side effects triggered by the action.
        package let effects: [Effect<Action>]
        
        init(state: State, effects: [Effect<Action>]) {
            self.state = state
            self.effects = effects
        }
    }
    
    /// The underlying closure that evaluates actions and mutates state.
    public let run: @Sendable (State, Action) -> Result
    
    /// Creates a new `Flow`.
    ///
    /// - Parameter run: A pure closure evaluating an action against the state.
    public init(run: @escaping @Sendable (State, Action) -> Result) {
        self.run = run
    }
}

extension Flow.Result {
    /// Creates a result that only updates the state, with no side effects.
    public static func result(_ state: State) -> Self {
        .init(state: state, effects: [])
    }

    /// Creates a result that updates the state and schedules a single side effect.
    public static func result(_ state: State, effect: Effect<Action>?) -> Self {
        .init(state: state, effects: effect.map { [$0] } ?? [])
    }
    
    /// Creates a result that updates the state and schedules multiple side effects.
    static func result(_ state: State, effects: [Effect<Action>]) -> Self {
        .init(state: state, effects: effects)
    }
}

public extension Flow {
    /// Transforms a child `Flow` into a parent `Flow` domain.
    ///
    /// This allows you to compose smaller, isolated features into a larger, complex application.
    ///
    /// - Parameters:
    ///   - childPath: A writable key path from the parent state to the child state.
    ///   - toChildAction: A closure extracting the child action from the parent action. Return `nil` if the action is not for this child.
    ///   - toParentAction: A closure wrapping a child action back into a parent action.
    /// - Returns: A new `Flow` operating on the parent domain.
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

    /// Combines multiple flows of the same domain into a single flow.
    ///
    /// The combined flow runs the provided flows sequentially. The mutated state from the first flow
    /// is passed to the second, and all resulting effects are merged.
    ///
    /// - Parameter flows: A variadic list of flows to combine.
    /// - Returns: A single merged `Flow`.
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
