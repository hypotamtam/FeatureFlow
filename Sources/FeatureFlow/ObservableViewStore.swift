#if canImport(Observation)
import Observation
import SwiftUI
import Foundation

private final class TaskCancellable: Sendable {
    private let task: Task<Void, Never>
    init(_ task: Task<Void, Never>) { self.task = task }
    deinit { task.cancel() }
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
    private let scopedStores = NSCache<ScopeCacheKey, AnyObject>()
    
    private final class ScopeCacheKey: NSObject {
        let stateKeyPath: AnyHashable
        let actionType: ObjectIdentifier
        
        init(stateKeyPath: AnyHashable, actionType: ObjectIdentifier) {
            self.stateKeyPath = stateKeyPath
            self.actionType = actionType
        }
        
        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(stateKeyPath)
            hasher.combine(actionType)
            return hasher.finalize()
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? ScopeCacheKey else { return false }
            return stateKeyPath == other.stateKeyPath && actionType == other.actionType
        }
    }
    
    public convenience init(initialState: State, flow: Flow<State, Action>) {
        self.init(store: Store(initialState: initialState, flow: flow))
    }
        
    init(store: Store<State, Action>) {
        self.store = store
        self.state = store.state
        
        let task = Task { @MainActor [weak self] in
            for await newState in store.stateStream {
                guard let self = self else { break }
                self.state = newState
            }
        }
        self.stateObservation = TaskCancellable(task)
    }
    
    public func send(_ action: Action) {
        store.send(action)
    }
    
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState>,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> ObservableViewStore<ChildState, ChildAction> {
        let key = ScopeCacheKey(stateKeyPath: childKeyPath, actionType: ObjectIdentifier(ChildAction.self))
        if let cached = scopedStores.object(forKey: key) as? ObservableViewStore<ChildState, ChildAction> {
            return cached
        }
        let scopedStore = ObservableViewStore<ChildState, ChildAction>(
            store: store.scope(state: childKeyPath, action: fromChildAction)
        )
        scopedStores.setObject(scopedStore, forKey: key)
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
            get: { self.store.state[keyPath: keyPath] },
            set: { _ in self.send(action) }
        )
    }
}
#endif
