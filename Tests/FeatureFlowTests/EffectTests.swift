// Tests/FeatureFlowTests/EffectTests.swift

import Testing
import Foundation
@testable import FeatureFlow

@Suite("Effect Tests")
struct EffectTests {
   
    @Test("Effect.cancel stops a running task")
    func effectCancel() async throws {
        let flow = Flow<TestAction> { state, action in
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
        let flow = Flow<TestAction> { state, action in
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
        var iterator = store.statePublisher.dropFirst().values.makeAsyncIterator()
        
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
        let flow = Flow<TestAction> { state, action in
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
}
