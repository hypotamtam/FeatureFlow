// Tests/FeatureFlowTests/ObservableViewStoreTests.swift

import Testing
import Foundation
import Observation
@testable import FeatureFlow

#if canImport(Observation)

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension ObservableViewStore {
    @MainActor
    func waitForNextStateUpdate(action: () -> Void) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = self.state
            } onChange: {
                // The onChange block fires *before* the property is actually updated (like willSet).
                // By dispatching to the MainActor, we enqueue the resumption to happen
                // *after* the current state assignment completes.
                Task { @MainActor in
                    continuation.resume()
                }
            }
            action()
        }
    }
}

@Suite("ObservableViewStore Tests")
struct ObservableViewStoreTests {

    @MainActor
    @Test("ObservableViewStore correctly updates state")
    func stateUpdates() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        #expect(viewStore.state.count == 0)
        
        await viewStore.waitForNextStateUpdate {
            viewStore.send(.increment(5))
        }
        
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
    @Test("ObservableViewStore releases scoped stores when no longer referenced and cleans up memory")
    func scopeIsReleased() async throws {
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
    @Test("ObservableViewStore.binding(to: Action) creates a working constant action binding")
    func constantActionBinding() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(count: 0), flow: baseTestFlow)
        let binding = viewStore.binding(\.count, to: .increment(10))
        
        #expect(binding.wrappedValue == 0)
        
        await viewStore.waitForNextStateUpdate {
            binding.wrappedValue = 999 // Value doesn't matter for constant action
        }
        
        #expect(viewStore.state.count == 10)
    }
    
    @MainActor
    @Test("Store.binding creates a working SwiftUI binding")
    func storeBinding() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let binding = viewStore.binding(\.text, to: { .setText($0) })
        
        await viewStore.waitForNextStateUpdate {
            binding.wrappedValue = "New Value"
        }
        
        #expect(viewStore.state.text == "New Value")
    }

    @MainActor
    @Test("ObservableViewStore removes duplicate state updates to prevent unnecessary rendering")
    func viewStoreRemovesDuplicates() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let viewStore = ObservableViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let stateTextUpdateCounter = Counter()
        
        // This wrapper allows the closure to hold a reference to itself for recursion.
        final class Observer: @unchecked Sendable {
            @MainActor var observe: (@Sendable @MainActor () -> Void)?
        }
        
        let observer = Observer()
        observer.observe = { @Sendable @MainActor [weak observer] in
            withObservationTracking {
                _ = viewStore.state.text
            } onChange: {
                Task { @MainActor in
                    await stateTextUpdateCounter.increment()
                    // RE-START: Since observation tracking is one-time, we must
                    // re-establish the track by calling the closure again.
                    observer?.observe?()
                }
            }
        }
        
        // KICKOFF: Start the first observation cycle.
        observer.observe?()
        
        // Initial change
        await viewStore.waitForNextStateUpdate {
            viewStore.send(.setText("First"))
        }
        
        // This should trigger a publish because the state changed from "" to "First"
        var textUpdateCount = await stateTextUpdateCounter.value
        #expect(textUpdateCount == 1)
        
        // Send the exact same action multiple times, followed by a new distinct one
        await viewStore.waitForNextStateUpdate {
            viewStore.send(.setText("First"))
            viewStore.send(.setText("First"))
            viewStore.send(.setText("First"))
            viewStore.send(.setText("Second"))
        }
        
        // The count should only be 2 because identical updates were dropped
        textUpdateCount = await stateTextUpdateCounter.value
        #expect(textUpdateCount == 2)
        #expect(viewStore.state.text == "Second")
    }
}
#endif

// Helper class for safe concurrent modification in the test
private actor Counter {
    var value = 0
    func increment() { value += 1 }
}
