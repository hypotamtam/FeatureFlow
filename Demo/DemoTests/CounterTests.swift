import Testing
import Foundation
@testable import FeatureFlow
@testable import Demo

class MockCounterResetService: CounterResetServiceProtocol {
    var startCalled = false
    var stopCalled = false
    func start() { startCalled = true }
    func stop() { stopCalled = true }
}

@Suite("Counter Domain Tests")
struct CounterTests {
    
    @Test("Incrementing the counter increases the count by 1")
    func increment() {
        let state = counterFlow.run(CounterState(), .increment).state
        #expect(state.count == 1)
    }

    @Test("Decrementing the counter decreases the count by 1")
    func decrement() {
        let state = counterFlow.run(CounterState(), .decrement).state
        #expect(state.count == -1)
    }

    @Test("A delayed increment action should set isProcessing to true")
    func delayedStartsLoading() {
        let state = counterFlow.run(CounterState(), .delayedIncrement).state
        #expect(state.isProcessing == true)
    }

    @MainActor
    @Test("The delayed increment effect should eventually produce an increment action")
    func delayedEffectReturnsIncrement() async throws {
        let result = counterFlow.run(CounterState(), .delayedIncrement)
        let effect = try #require(result.effects.first)
        let nextAction = await effect.operation()
        #expect(nextAction == .increment)
    }

    @Test("Resetting the counter sets count to 0 and waits for a new reset signal")
    func reset() {
        let state = CounterState(count: 10)
        let result = counterFlow.run(state, .reset)
        
        #expect(result.state.count == 0)
        #expect(result.effects.count == 1)
    }

    @Test("Starting monitoring starts the service and begins waiting for signals")
    func startMonitoring() {
        let mock = MockCounterResetService()
        Current.counterResetService = mock
        
        let result = counterFlow.run(CounterState(), .startMonitoring)
        
        #expect(mock.startCalled == true)
        #expect(result.effects.count == 1)
    }
}
