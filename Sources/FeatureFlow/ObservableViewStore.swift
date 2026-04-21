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

private final class DeinitObserver: Sendable {
    private let onDeinit: @Sendable () -> Void
    init(onDeinit: @escaping @Sendable () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

/// A SwiftUI wrapper for `Store` that leverages the modern `@Observable` macro.
///
/// Use `ObservableViewStore` to connect your feature's state and actions to a SwiftUI view 
/// in iOS 17+, macOS 14+, tvOS 17+, and watchOS 10+. It observes the underlying store's state stream 
/// and triggers view updates only when necessary.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Observable
@MainActor
public final class ObservableViewStore<State: FeatureFlow.State, Action: Sendable> {
    
    /// The current state of the feature. Accessing this property in a SwiftUI view body 
    /// registers the view to automatically update when the state changes.
    public private(set) var state: State
    
    @ObservationIgnored
    private let store: Store<State, Action>
    
    @ObservationIgnored
    private var stateObservation: TaskCancellable?

    @ObservationIgnored
    private var deinitObserver: DeinitObserver?
    
    @ObservationIgnored
    private var scopedStores: [ScopeKey: AnyWeakObservableViewStore] = [:]

    @ObservationIgnored
    private var scopeIDs: [UUID: ScopeKey] = [:]

    #if canImport(Testing)
    internal var _scopedStoresCount: Int {
        scopedStores.count
    }
    #endif
    
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
    
    /// Initializes a new view store with a starting state and a flow.
    ///
    /// - Parameters:
    ///   - initialState: The starting state of the feature.
    ///   - flow: The business logic that determines how the state changes in response to actions.
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
    
    /// Sends an action to the underlying store.
    ///
    /// - Parameter action: The action to perform.
    public func send(_ action: Action) {
        store.send(action)
    }
    
    /// Creates a child view store scoped to a specific domain using a `CasePath`.
    ///
    /// - Parameters:
    ///   - childKeyPath: A key path extracting the child state from the parent state.
    ///   - casePath: A case path for embedding the child action into the parent action.
    /// - Returns: A new `ObservableViewStore` operating on the child domain.
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState> & Sendable,
        action casePath: CasePath<Action, ChildAction>
    ) -> ObservableViewStore<ChildState, ChildAction> {
        self.scope(
            state: childKeyPath,
            action: casePath.embed
        )
    }

    /// Creates a child view store scoped to a specific domain.
    ///
    /// - Parameters:
    ///   - childKeyPath: A key path extracting the child state from the parent state.
    ///   - fromChildAction: A closure wrapping a child action into a parent action.
    /// - Returns: A new `ObservableViewStore` operating on the child domain.
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
        
        let removalID = UUID()
        scopeIDs[removalID] = key
        
        // Cleanup this specific key from memory when the scoped store is deallocated.
        // This is O(1) compared to filtering the entire dictionary.
        scopedStore.deinitObserver = DeinitObserver { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let key = self.scopeIDs.removeValue(forKey: removalID) {
                    // Only remove if the reference is truly dead (prevents race conditions)
                    if self.scopedStores[key]?.isAlive == false {
                        self.scopedStores.removeValue(forKey: key)
                    }
                }
            }
        }

        scopedStores[key] = WeakStore(scopedStore)
        
        return scopedStore
    }

    /// Creates a standard SwiftUI `Binding` for a property in the state.
    ///
    /// The setter of this binding dispatches an action back to the store.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a value inside the state.
    ///   - action: A closure that takes the new value and returns an action to dispatch.
    /// - Returns: A SwiftUI binding.
    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        to action: @escaping @Sendable (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            // We read from store.state rather than self.state to avoid "rubber-banding" glitches.
            // Since self.state is updated asynchronously via AsyncStream, reading from it 
            // directly in a binding's getter could return a stale value immediately after 
            // an action is sent, causing the UI to briefly snap back to the old value.
            get: { self.store.state[keyPath: keyPath] },
            set: { self.send(action($0)) }
        )
    }

    /// Creates a standard SwiftUI `Binding` for a property in the state, using a `CasePath` to embed the value into an action.
    ///
    /// The setter of this binding dispatches the action with the new value back to the store using the `CasePath`'s embed function.
    ///
    /// ```swift
    /// Toggle("Enabled", isOn: viewStore.binding(\.isEnabled, to: .isEnabledChanged))
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a value inside the state.
    ///   - casePath: A case path for embedding the updated value into the feature's action.
    /// - Returns: A SwiftUI binding.
    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        to casePath: CasePath<Action, Value>
    ) -> Binding<Value> {
        self.binding(keyPath, to: casePath.embed)
    }

    /// Creates a standard SwiftUI `Binding` for a property in the state, dispatching a constant action on change.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a value inside the state.
    ///   - action: The action to dispatch whenever the binding is modified.
    /// - Returns: A SwiftUI binding.
    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        to action: Action
    ) -> Binding<Value> {
        Binding(
            // We read from store.state rather than self.state to avoid "rubber-banding" glitches.
            get: { self.store.state[keyPath: keyPath] },
            set: { _ in self.send(action) }
        )
    }
}
#endif
