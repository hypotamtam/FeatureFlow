// Tests/FeatureFlowTests/ViewStoreTests.swift

import Testing
import Combine
@testable import FeatureFlow

@Suite("ViewStore Tests")
struct ViewStoreTests {

    @MainActor
    @Test("Store.binding creates a working SwiftUI binding")
    func storeBinding() async throws {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let binding = viewStore.binding(\.text, to: { .setText($0) })
        
        binding.wrappedValue = "New Value"
        
        var isDone = false
        var sleepTime = 0
        while isDone == false {
            try await Task.sleep(nanoseconds: 10_000)
            sleepTime += 10_000
            isDone = (viewStore.state.text == "New Value") || (sleepTime == 100_000)
        }
        #expect(viewStore.state.text == "New Value")
    }

    @MainActor
    @Test("ViewStore.scope returns the same instance for identical scopes")
    func viewStoreScopeIsMemoized() {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        // 1. Create two identical scopes
        let child1 = viewStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        
        let child2 = viewStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        
        // 2. Assert they are the exact same object reference
        #expect(child1 === child2)
    }

    @MainActor
    @Test("ViewStore removes duplicate state updates to prevent unnecessary rendering")
    func viewStoreRemovesDuplicates() async throws {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        var publishCount = 0
        let cancellable = viewStore.objectWillChange.sink { _ in
            publishCount += 1
        }
        
        // Initial change
        viewStore.send(.setText("First"))
        
        // Yield to allow the Combine pipeline (which receives on Main thread) to process
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // This should trigger a publish because the state changed from "" to "First"
        #expect(publishCount == 1)
        
        // Send the exact same action multiple times
        viewStore.send(.setText("First"))
        viewStore.send(.setText("First"))
        viewStore.send(.setText("First"))
        
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // The count should still be 1 because .removeDuplicates() caught the identical state updates
        #expect(publishCount == 1)
        
        // Send a new change to verify it can still update
        viewStore.send(.setText("Second"))
        
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(publishCount == 2)
        
        // Keep a reference so it's not deallocated early
        _ = cancellable
    }
}
