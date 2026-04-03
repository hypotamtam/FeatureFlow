// Tests/FeatureFlowTests/EffectTests.swift

import Testing
import Foundation
@testable import FeatureFlow

@Suite("Effect Tests")
struct EffectTests {
   
    @Test("Effect.cancel stops a running task")
    func effectCancel() async throws {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .asyncIncrement(let id, _, let value):
                return .result(
                    state,
                    effect: Effect(id: id) {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                        return .increment(value)
                    }
                )
            case .setText(let id):
                // Using setText as a trigger to send a cancel effect
                return .result(state, effect: .cancel(id: id))
            default:
                return .result(state)
            }
        }
        
        let store = Store(initialState: TestState(), flow: flow)
        
        // Start a long running task
        store.send(.asyncIncrement(id: "cancel-me", policy: .cancelPrevious, value: 10))
        
        // Wait briefly to ensure the task has started
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Send cancellation
        store.send(.setText("cancel-me"))
        
        // Wait long enough for the original task to have finished if it wasn't cancelled
        try await Task.sleep(nanoseconds: 600_000_000)
        
        // State should remain 0 because the increment was cancelled
        #expect(store.state.count == 0)
    }

    @Test("Effect.debounce only executes the last call within the window")
    func effectDebounce() async throws {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case let .setText(val):
                return .result(
                    state,
                    effect: .debounce(id: "debounce-id", for: 0.3) {
                        .increment(val.count)
                    }
                )
            case .increment(let val):
                return .result(state.with { $0.count = val })
            default:
                return .result(state)
            }
            
        }
        
        let store = Store(initialState: TestState(), flow: flow)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        // Send multiple actions rapidly
        store.send(.setText("a"))      // 0.0s
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        store.send(.setText("ab"))     // 0.01s
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        store.send(.setText("abc"))    // 0.02s
        
    
        let _ = await iterator.next()
        #expect(store.state.count == 3)
    }

    @Test("Effect.throttle ignores subsequent calls while one is active")
    func effectThrottle() async throws {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case let .increment(val):
                return .result(
                    state,
                    effect: .throttle(id: "throttle-id") {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                        return .setText("\(val)")
                    }
                )
            case .setText(let text):
                return .result(state.with { $0.text = text })
            default:
                return .result(state)
            }
        }
        
        let store = Store(initialState: TestState(), flow: flow)
        
        // Start first throttled effect
        store.send(.increment(1)) // Ends at 0.3s
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Attempt to send another while the first is running
        store.send(.increment(2)) // Should be ignored
        
        try await Task.sleep(nanoseconds: 400_000_000) // Total 0.5s
        
        // Only the first action (value 1) should have processed
        #expect(store.state.text == "1")
    }
    
    @Test("EffectPolicy.cancelPrevious cancels existing tasks with same ID")
    func effectCancellation() async throws {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        
        // Send two async increments with the same ID
        store.send(.asyncIncrement(id: "id", policy: .cancelPrevious, value: 1))
        // Wait slightly to ensure task is created
        try await Task.sleep(nanoseconds: 10_000_000)
        
        store.send(.asyncIncrement(id: "id", policy: .cancelPrevious, value: 2))
        
        // Wait for the duration of one effect (0.1s + buffer)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Only one increment should have succeeded (the first was cancelled)
        #expect(store.state.count == 2)
    }

    @Test("EffectPolicy.runIfMissing ignores new tasks if ID is active")
    func effectThrottling() async throws {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        
        // Send first async increment
        store.send(.asyncIncrement(id: "id", policy: .runIfMissing, value: 1))
        // Send second one immediately - should be ignored
        store.send(.asyncIncrement(id: "id", policy: .runIfMissing, value: 2))
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Only the first one should have counted
        #expect(store.state.count == 1)
    }

    @Test("Effect handles rapid cancellation without clearing newer tasks")
    func effectRapidCancellation() async throws {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .asyncIncrement(let id, let policy, let value):
                return .result(
                    state,
                    effect: Effect(id: id, policy: policy) {
                        do {
                            // Sleep enough time so we can cancel it
                            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                            return .increment(value)
                        } catch {
                            return nil
                        }
                    }
                )
            case .increment(let value):
                // We add to count so we can see if multiple tasks succeed
                return .result(state.with { $0.count += value })
            default:
                return .result(state)
            }
        }
        
        let store = Store(initialState: TestState(), flow: flow)
        
        // Task 1: Will be cancelled
        store.send(.asyncIncrement(id: "rapid", policy: .cancelPrevious, value: 10))
        
        // Let Task 1 start
        try await Task.sleep(nanoseconds: 10_000_000)
        
        // Task 2: Cancels Task 1. Task 1 will wake up and try to clear the dict.
        store.send(.asyncIncrement(id: "rapid", policy: .cancelPrevious, value: 100))
        
        // Wait long enough for Task 1 to finish its cancellation handler,
        // but not long enough for Task 2 to finish its 0.1s sleep.
        try await Task.sleep(nanoseconds: 20_000_000)
        
        // Task 3: Should cancel Task 2. If the bug exists, Task 1 cleared the dict,
        // so Task 3 won't find Task 2 to cancel it!
        store.send(.asyncIncrement(id: "rapid", policy: .cancelPrevious, value: 1000))
        
        // Wait for everything to finish
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // If bug exists: Task 2 and Task 3 both complete. Count = 1100.
        // If fixed: Task 1 and 2 are cancelled, only Task 3 completes. Count = 1000.
        #expect(store.state.count == 1000)
    }
}
