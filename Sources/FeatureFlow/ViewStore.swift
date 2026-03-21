import Foundation
import Combine
import SwiftUI

@MainActor
public final class ViewStore<Action: FeatureFlow.Action>: ObservableObject {
    
    @Published public private(set) var state: Action.State
    
    private let store: Store<Action>
    
    public convenience init(initialState: Action.State, flow: Flow<Action>) {
        self.init(store: Store(initialState: initialState, flow: flow))
    }
        
    init(store: Store<Action>) {
        self.store = store
        self.state = store.state
        
        store.statePublisher
            .dropFirst()
            .receive(on: DispatchQueue.main) 
            .assign(to: &$state)
    }
    
    public func send(_ action: Action) {
        store.send(action)
    }
    
    public func scope<ChildAction>(
        state childKeyPath: KeyPath<Action.State, ChildAction.State>,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> ViewStore<ChildAction> {
        ViewStore<ChildAction>(
            store: store.scope(state: childKeyPath, action: fromChildAction)
        )
    }

    public func binding<Value>(
        _ keyPath: KeyPath<Action.State, Value>,
        to action: @escaping @Sendable (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.store.state[keyPath: keyPath] },
            set: { self.send(action($0)) }
        )
    }
}
