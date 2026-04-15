// Tests/FeatureFlowTests/ViewStoreTests.swift

import Testing
import Combine
import Foundation
@testable import FeatureFlow

extension ViewStore {
    @MainActor
    func waitForNextStateUpdate(action: () -> Void) async {
        var cancellable: AnyCancellable?
        await withCheckedContinuation { continuation in
            cancellable = self.$state.dropFirst().first().sink { state in
                continuation.resume()
            }
            action()
        }
        cancellable?.cancel()
    }
}

@Suite("ViewStore Tests")
struct ViewStoreTests {

    @MainActor
    @Test("ViewStore correctly updates state")
    func stateUpdates() async throws {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        #expect(viewStore.state.count == 0)
        
        await viewStore.waitForNextStateUpdate {
            viewStore.send(.increment(5))
        }
        
        #expect(viewStore.state.count == 5)
    }

    @MainActor
    @Test("Store.binding creates a working SwiftUI binding")
    func storeBinding() async throws {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let binding = viewStore.binding(\.text, to: { .setText($0) })
        
        await viewStore.waitForNextStateUpdate {
            binding.wrappedValue = "New Value"
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
    @Test("ViewStore releases scoped stores when no longer referenced and cleans up memory")
    func scopeIsReleased() async throws {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        weak var weakChild: ViewStore<SubState, SubAction>?
        
        autoreleasepool {
            let child = viewStore.scope(
                state: \.child,
                action: { .childAction($0) }
            )
            weakChild = child
            #expect(weakChild != nil)
            #expect(viewStore._scopedStoresCount == 1)
        }
        
        // After autoreleasepool, the only reference should have been the dictionary
        // Since the dictionary holds it weakly, it should be nil
        #expect(weakChild == nil)
        
        // Yield to allow our O(1) async cleanup Task to execute
        try await Task.sleep(nanoseconds: 10_000_000)
        
        // Assert the cleanup succeeded without needing another scope() call
        #expect(viewStore._scopedStoresCount == 0)
    }
    
    @MainActor
    @Test("ViewStore.binding(to: Action) creates a working constant action binding")
    func constantActionBinding() async throws {
        let viewStore = ViewStore(initialState: TestState(count: 0), flow: baseTestFlow)
        let binding = viewStore.binding(\.count, to: .increment(10))
        
        #expect(binding.wrappedValue == 0)
        
        await viewStore.waitForNextStateUpdate {
            binding.wrappedValue = 999 // Value doesn't matter for constant action
        }
        
        #expect(viewStore.state.count == 10)
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
        await viewStore.waitForNextStateUpdate {
            viewStore.send(.setText("First"))
        }
        
        // This should trigger a publish because the state changed from "" to "First"
        #expect(publishCount == 1)
        
        // Send the exact same action multiple times, followed by a new change
        await viewStore.waitForNextStateUpdate {
            viewStore.send(.setText("First"))
            viewStore.send(.setText("First"))
            viewStore.send(.setText("First"))
            viewStore.send(.setText("Second"))
        }
        
        // The count should only be 2 because identical updates were dropped
        #expect(publishCount == 2)
        #expect(viewStore.state.text == "Second")
        
        // Keep a reference so it's not deallocated early
        _ = cancellable
    }
}
