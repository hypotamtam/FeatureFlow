// Tests/FeatureFlowTests/ObservableViewStoreTests.swift

import Testing
import Foundation
@testable import FeatureFlow

#if canImport(Observation)
@Suite("ObservableViewStore Tests")
struct ObservableViewStoreTests {

    @MainActor
    @Test("ObservableViewStore correctly updates state")
    func stateUpdates() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        #expect(viewStore.state.count == 0)
        
        viewStore.send(.increment(5))
        
        // Wait for AsyncStream to process
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(viewStore.state.count == 5)
    }

    @MainActor
    @Test("ObservableViewStore.scope returns the same instance for identical scopes")
    func scopeIsMemoized() {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let child1 = viewStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        
        let child2 = viewStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        
        #expect(child1 === child2)
    }

    @MainActor
    @Test("ObservableViewStore.binding(to: Action) creates a working constant action binding")
    func constantActionBinding() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(count: 0), flow: baseTestFlow)
        let binding = viewStore.binding(\.count, to: .increment(10))
        
        #expect(binding.wrappedValue == 0)
        
        binding.wrappedValue = 999 // Value doesn't matter for constant action
        
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(viewStore.state.count == 10)
    }
}
#endif
