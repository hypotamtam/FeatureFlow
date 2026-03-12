import Foundation
import Combine
import SwiftUI

@MainActor
public class Store<Action: FeatureFlow.Action>: ObservableObject {
    
    @Published public private(set) var state: Action.State
    
    private let flow: Flow<Action>?
    private let onAction: ((Action) -> Void)?
    
    private var tasks: [AnyHashable: Task<Void, Never>] = [:]
    
    public init(initialState: Action.State, flow: Flow<Action>) {
        self.state = initialState
        self.flow = flow
        self.onAction = nil
    }
    
    private init(
        initialState: Action.State,
        onAction: @escaping (Action) -> Void,
        publisher: AnyPublisher<Action.State, Never>
    ) {
        self.state = initialState
        self.flow = nil
        self.onAction = onAction
        publisher
            .assign(to: &$state)
    }
    
    public func send(_ action: Action) {
        if let flow = flow {
            let result = flow.run(state, action)
            state = result.state
            
            for effect in result.effects {
                execute(effect)
            }
        } else if let onAction = onAction {
            onAction(action)
        }
    }

    private func execute(_ effect: Effect<Action>) {
        if let id = effect.id {
            if effect.policy == .cancelPrevious {
                tasks[id]?.cancel()
            } else if effect.policy == .runIfMissing, tasks[id] != nil {
                return
            }
        }

        let task = Task { [weak self] in
            let nextAction = await effect.operation()
            
            guard let self = self else { return }

            if let id = effect.id, !Task.isCancelled {
                self.tasks[id] = nil
            }

            if !Task.isCancelled, let nextAction = nextAction {
                self.send(nextAction)
            }
        }

        if let id = effect.id {
            tasks[id] = task
        }
    }
    
    public func scope<ChildAction>(
        state childKeyPath: KeyPath<Action.State, ChildAction.State>,
        action fromChildAction: @escaping (ChildAction) -> Action
    ) -> Store<ChildAction> {
        Store<ChildAction>(
            initialState: state[keyPath: childKeyPath],
            onAction: { [weak self] childAction in
                self?.send(fromChildAction(childAction))
            },
            publisher: $state
                .map(childKeyPath)
                .eraseToAnyPublisher()
        )
    }

    public func binding<Value>(
        _ keyPath: KeyPath<Action.State, Value>,
        to action: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.send(action($0)) }
        )
    }
}
