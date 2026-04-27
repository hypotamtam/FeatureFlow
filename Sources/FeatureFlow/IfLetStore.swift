import SwiftUI
import Foundation

#if canImport(Observation)
/// A SwiftUI view that safely unwraps an optional child state and provides a scoped store to its content.
///
/// `IfLetStore` automatically handles the complex SwiftUI dismissal lifecycle by caching the last-known
/// non-nil state during dismissal animations, preventing crashes.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct IfLetStore<ParentState: State, ParentAction: Sendable, ChildState: State, ChildAction: Sendable, Content: View>: View {
    private let store: ObservableViewStore<ParentState, ParentAction>
    private let stateKeyPath: KeyPath<ParentState, ChildState?> & Sendable
    private let fromChildAction: @Sendable (ChildAction) -> ParentAction
    private let content: (ObservableViewStore<ChildState, ChildAction>) -> Content
    
    @SwiftUI.State private var cachedChildStore: ObservableViewStore<ChildState, ChildAction>?
    
    public init(
        store: ObservableViewStore<ParentState, ParentAction>,
        state stateKeyPath: KeyPath<ParentState, ChildState?> & Sendable,
        action fromChildAction: @escaping @Sendable (ChildAction) -> ParentAction,
        @ViewBuilder content: @escaping (ObservableViewStore<ChildState, ChildAction>) -> Content
    ) {
        self.store = store
        self.stateKeyPath = stateKeyPath
        self.fromChildAction = fromChildAction
        self.content = content
    }

    public init(
        store: ObservableViewStore<ParentState, ParentAction>,
        state stateKeyPath: KeyPath<ParentState, ChildState?> & Sendable,
        action casePath: CasePath<ParentAction, ChildAction>,
        @ViewBuilder content: @escaping (ObservableViewStore<ChildState, ChildAction>) -> Content
    ) {
        self.init(
            store: store,
            state: stateKeyPath,
            action: casePath.embed,
            content: content
        )
    }

    public var body: some View {
        Group {
            if let childStore = cachedChildStore ?? store.scope(state: stateKeyPath, action: fromChildAction) {
                content(childStore)
            }
        }
        .onAppear {
            updateCache()
        }
        .onChange(of: store.state) {
            updateCache()
        }
    }
    
    private func updateCache() {
        if store.state[keyPath: stateKeyPath] != nil {
            // Only create the child store if we don't already have one.
            // The child store automatically receives state updates via its internal state stream,
            // so we don't need to recreate it.
            if cachedChildStore == nil {
                cachedChildStore = store.scope(state: stateKeyPath, action: fromChildAction)
            }
        } else {
            // We do not set to nil immediately. 
            // We let the view deinit when the presentation (sheet/etc) finishes its animation.
        }
    }
}
#endif

/// A legacy SwiftUI view that safely unwraps an optional child state and provides a scoped store to its content.
///
/// Designed for `ViewStore` in iOS 16 and below.
public struct LegacyIfLetStore<ParentState: State, ParentAction: Sendable, ChildState: State, ChildAction: Sendable, Content: View>: View {
    @ObservedObject private var store: ViewStore<ParentState, ParentAction>
    private let stateKeyPath: KeyPath<ParentState, ChildState?> & Sendable
    private let fromChildAction: @Sendable (ChildAction) -> ParentAction
    private let content: (ViewStore<ChildState, ChildAction>) -> Content
    
    @SwiftUI.State private var cachedChildStore: ViewStore<ChildState, ChildAction>?
    
    public init(
        store: ViewStore<ParentState, ParentAction>,
        state stateKeyPath: KeyPath<ParentState, ChildState?> & Sendable,
        action fromChildAction: @escaping @Sendable (ChildAction) -> ParentAction,
        @ViewBuilder content: @escaping (ViewStore<ChildState, ChildAction>) -> Content
    ) {
        self.store = store
        self.stateKeyPath = stateKeyPath
        self.fromChildAction = fromChildAction
        self.content = content
    }

    public init(
        store: ViewStore<ParentState, ParentAction>,
        state stateKeyPath: KeyPath<ParentState, ChildState?> & Sendable,
        action casePath: CasePath<ParentAction, ChildAction>,
        @ViewBuilder content: @escaping (ViewStore<ChildState, ChildAction>) -> Content
    ) {
        self.init(
            store: store,
            state: stateKeyPath,
            action: casePath.embed,
            content: content
        )
    }

    public var body: some View {
        Group {
            if let childStore = cachedChildStore ?? store.scope(state: stateKeyPath, action: fromChildAction) {
                content(childStore)
            }
        }
        .onAppear {
            updateCache()
        }
        .onChange(of: store.state) { _ in
            updateCache()
        }
    }
    
    private func updateCache() {
        if store.state[keyPath: stateKeyPath] != nil {
            if cachedChildStore == nil {
                cachedChildStore = store.scope(state: stateKeyPath, action: fromChildAction)
            }
        } else {
            // We do not set to nil immediately. 
            // We let the view deinit when the presentation (sheet/etc) finishes its animation.
        }
    }
}
