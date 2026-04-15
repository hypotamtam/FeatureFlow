import Foundation
import Combine
import SwiftUI

private protocol AnyWeakViewStore {
    var isAlive: Bool { get }
}

private final class DeinitObserver: Sendable {
    private let onDeinit: @Sendable () -> Void
    init(onDeinit: @escaping @Sendable () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

/// A SwiftUI wrapper for `Store` that leverages the older `@ObservedObject` protocol.
///
/// Use `ViewStore` to connect your feature's state and actions to a SwiftUI view in 
/// OS versions prior to iOS 17 / macOS 14. For newer platforms, prefer `ObservableViewStore`.
@available(iOS, deprecated: 17.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@available(macOS, deprecated: 14.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@available(tvOS, deprecated: 17.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@available(watchOS, deprecated: 10.0, message: "Use ObservableViewStore for better performance and modern SwiftUI support.")
@MainActor
public final class ViewStore<State: FeatureFlow.State, Action: Sendable>: ObservableObject {
    
    /// The current state of the feature. View updates are triggered when this property changes.
    @Published public private(set) var state: State
    
    private let store: Store<State, Action>
    
    private var scopedStores: [ScopeKey: AnyWeakViewStore] = [:]

    private var scopeIDs: [UUID: ScopeKey] = [:]

    private var deinitObserver: DeinitObserver?
    
    #if canImport(Testing)
    internal var _scopedStoresCount: Int {
        scopedStores.count
    }
    #endif

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
    /// - Returns: A new `ViewStore` operating on the child domain.
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState> & Sendable,
        action casePath: CasePath<Action, ChildAction>
    ) -> ViewStore<ChildState, ChildAction> {
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
    /// - Returns: A new `ViewStore` operating on the child domain.
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
