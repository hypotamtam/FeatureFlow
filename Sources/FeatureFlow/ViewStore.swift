import Foundation
import Combine
import SwiftUI

private protocol AnyWeakViewStore {
    var isAlive: Bool { get }
}

@available(iOS, deprecated: 17.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@available(macOS, deprecated: 14.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@available(tvOS, deprecated: 17.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@available(watchOS, deprecated: 10.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@MainActor
public final class ViewStore<State: FeatureFlow.State, Action: Sendable>: ObservableObject {
    
    @Published public private(set) var state: State
    
    private let store: Store<State, Action>
    
    private var scopedStores: [ScopeKey: AnyWeakViewStore] = [:]
    
    private var stateObservation: Task<Void, Never>?
    
    private struct ScopeKey: Hashable {
        let stateKeyPath: AnyHashable
        let actionType: ObjectIdentifier
    }
    
    private final class WeakStore<ChildState: FeatureFlow.State, ChildAction: Sendable>: AnyWeakViewStore {
        weak var store: ViewStore<ChildState, ChildAction>?
        init(_ store: ViewStore<ChildState, ChildAction>) {
            self.store = store
        }
        var isAlive: Bool { store != nil }
    }
    
    public convenience init(initialState: State, flow: Flow<State, Action>) {
        self.init(store: Store(initialState: initialState, flow: flow))
    }
    
    init(store: Store<State, Action>) {
        self.store = store
        self.state = store.state
        
        self.stateObservation = Task { [weak self] in
            for await newState in store.stateStream {
                guard let self else { break }
                    self.state = newState
            }
        }
    }

    deinit {
        stateObservation?.cancel()
    }
    
    public func send(_ action: Action) {
        store.send(action)
    }
    
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState> & Sendable,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> ViewStore<ChildState, ChildAction> {
        let key = ScopeKey(stateKeyPath: childKeyPath, actionType: ObjectIdentifier(ChildAction.self))
        
        if let weakStore = scopedStores[key] as? WeakStore<ChildState, ChildAction>,
           let cached = weakStore.store {
            return cached
        }
        
        let scopedStore = ViewStore<ChildState, ChildAction>(
            store: store.scope(state: childKeyPath, action: fromChildAction)
        )
        scopedStores[key] = WeakStore(scopedStore)
        
        // Cleanup dead weak references to keep the dictionary small
        scopedStores = scopedStores.filter { $0.value.isAlive }
        
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

    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        to action: Action
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { _ in self.send(action) }
        )
    }
}
