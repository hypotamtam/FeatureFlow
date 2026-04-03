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
    @Test("ObservableViewStore releases scoped stores when no longer referenced")
    func scopeIsReleased() {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        weak var weakChild: ObservableViewStore<SubState, SubAction>?
        
        autoreleasepool {
            let child = viewStore.scope(
                state: \.child,
                action: { .childAction($0) }
            )
            weakChild = child
            #expect(weakChild != nil)
        }
        
        // After autoreleasepool, the only reference should have been the dictionary
        // Since the dictionary holds it weakly, it should be nil
        #expect(weakChild == nil)
        
        // Create another scope to trigger the cleanup filter
        _ = viewStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
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
    @MainActor
    @Test("Store.binding creates a working SwiftUI binding")
    func storeBinding() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
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
    @Test("ObservableViewStore removes duplicate state updates to prevent unnecessary rendering")
    func viewStoreRemovesDuplicates() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let counter = Counter()
        
        // In @Observable, we don't have publishers. To test "re-renders" (observations),
        // we use withObservationTracking, which is what SwiftUI uses under the hood.
        // It only fires ONCE, so we need a recursive loop to keep watching for changes.
        
        // This wrapper allows the closure to hold a reference to itself for recursion.
        final class Observer: @unchecked Sendable {
            @MainActor var observe: (@Sendable @MainActor () -> Void)?
        }
        
        let observer = Observer()
        observer.observe = { @Sendable @MainActor [weak observer] in
            withObservationTracking {
                // 1. Tell the system we are "reading" (watching) this specific property.
                _ = viewStore.state.text
            } onChange: {
                // 2. This block fires exactly once when the property we read is about to change.
                Task { @MainActor in
                    await counter.increment()
                    // 3. RE-START: Since observation tracking is one-time, we must 
                    // re-establish the track by calling the closure again.
                    observer?.observe?()
                }
            }
        }
        
        // KICKOFF: Start the first observation cycle.
        observer.observe?()
        
        // Initial change
        viewStore.send(.setText("First"))
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // This should trigger a publish because the state changed from "" to "First"
        let count1 = await counter.value
        #expect(count1 == 1)
        
        // Send the exact same action multiple times
        viewStore.send(.setText("First"))
        viewStore.send(.setText("First"))
        viewStore.send(.setText("First"))
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // The count should still be 1 because Store catches identical state updates
        let count2 = await counter.value
        #expect(count2 == 1)
        
        // Send a new change to verify it can still update
        viewStore.send(.setText("Second"))
        try await Task.sleep(nanoseconds: 50_000_000)
        
        let count3 = await counter.value
        #expect(count3 == 2)
    }
}
#endif

// Helper class for safe concurrent modification in the test
private actor Counter {
    var value = 0
    func increment() { value += 1 }
}
