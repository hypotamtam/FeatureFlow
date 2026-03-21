// Tests/FeatureFlowTests/StoreTests.swift

import Testing
import Foundation
@testable import FeatureFlow

@Suite("Store Tests")
struct StoreTests {

    @Test("Store updates state and notifies observers")
    func storeStateUpdates() async {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        
        store.send(.increment(1))
        #expect(store.state.count == 1)
        
        store.send(.setText("Hello"))
        #expect(store.state.text == "Hello")
    }

    @Test("Store.scope creates a child store that synchronizes with the parent")
    func storeScoping() async throws {
        let parentStore = Store(initialState: TestState(), flow: combinedTestFlow)
        let childStore = parentStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        
        #expect(childStore.state.value == 0)
        
        // Send to child store
        childStore.send(.increment)
        
        // Wait for @Published propagation via Combine
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(parentStore.state.child.value == 1)
        #expect(childStore.state.value == 1)
    }

    @Test("Store handles concurrent sends correctly")
    func storeConcurrentSends() async {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        let count = 1000
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask {
                    store.send(.increment(1))
                }
            }
        }
        
        #expect(store.state.count == count)
    }
}
