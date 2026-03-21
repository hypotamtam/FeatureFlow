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
}
