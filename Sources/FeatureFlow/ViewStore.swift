import Foundation
import Combine
import SwiftUI

@MainActor
public final class ViewStore<State: FeatureFlow.State, Action: Sendable>: ObservableObject {
    
    @Published public private(set) var state: State
    
    private let store: Store<State, Action>
    
    public convenience init(initialState: State, flow: Flow<State, Action>) {
        self.init(store: Store(initialState: initialState, flow: flow))
    }
        
    init(store: Store<State, Action>) {
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
    
    private var scopedStores: [AnyHashable: Any] = [:]
    
    private struct ScopeKey: Hashable {
        let stateKeyPath: AnyHashable
        let actionType: ObjectIdentifier
    }
    
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState>,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> ViewStore<ChildState, ChildAction> {
        let key = ScopeKey(stateKeyPath: childKeyPath, actionType: ObjectIdentifier(ChildAction.self))
        if let cached = scopedStores[key] as? ViewStore<ChildState, ChildAction> {
            return cached
        }
        let scopedStore = ViewStore<ChildState, ChildAction>(
            store: store.scope(state: childKeyPath, action: fromChildAction)
        )
        scopedStores[key] = scopedStore
        return scopedStore
    }

    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        to action: @escaping @Sendable (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.store.state[keyPath: keyPath] },
            set: { self.send(action($0)) }
        )
    }
}
