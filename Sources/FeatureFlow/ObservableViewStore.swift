#if canImport(Observation)
import Observation
import SwiftUI
import Foundation

private final class TaskCancellable: Sendable {
    private let task: Task<Void, Never>
    init(_ task: Task<Void, Never>) { self.task = task }
    deinit { task.cancel() }
}

private protocol AnyWeakObservableViewStore {
    var isAlive: Bool { get }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Observable
@MainActor
public final class ObservableViewStore<State: FeatureFlow.State, Action: Sendable> {
    
    public private(set) var state: State
    
    @ObservationIgnored
    private let store: Store<State, Action>
    
    @ObservationIgnored
    private var stateObservation: TaskCancellable?
    
    @ObservationIgnored
    private var scopedStores: [ScopeKey: AnyWeakObservableViewStore] = [:]
    
    private struct ScopeKey: Hashable {
        let stateKeyPath: AnyHashable
        let actionType: ObjectIdentifier
    }
    
    private final class WeakStore<ChildState: FeatureFlow.State, ChildAction: Sendable>: AnyWeakObservableViewStore {
        weak var store: ObservableViewStore<ChildState, ChildAction>?
        init(_ store: ObservableViewStore<ChildState, ChildAction>) {
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
        
        let task = Task { [weak self] in
            for await newState in store.stateStream {
                guard let self else { break }
                    self.state = newState
            }
        }
        self.stateObservation = TaskCancellable(task)
    }
    
    public func send(_ action: Action) {
        store.send(action)
    }
    
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState> & Sendable,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> ObservableViewStore<ChildState, ChildAction> {
        let key = ScopeKey(stateKeyPath: childKeyPath, actionType: ObjectIdentifier(ChildAction.self))
        
        if let weakStore = scopedStores[key] as? WeakStore<ChildState, ChildAction>,
           let cached = weakStore.store {
            return cached
        }
        
        let scopedStore = ObservableViewStore<ChildState, ChildAction>(
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
#endif
