import Testing
import Foundation
import FeatureFlow
import FeatureFlowTesting
@testable import Demo

@MainActor
final class MockCounterResetService: CounterResetServiceProtocol {
    var startCalled = false
    var stopCalled = false
    
    private(set) var isStarted = false
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    
    var resetNotificationEmitter: AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.continuations[id] = nil
                }
            }
            self.continuations[id] = continuation
        }
    }
    
    func start() {
        startCalled = true
        isStarted = true
    }
    
    func emitReset() async {
        // Latch: wait until the effect has actually subscribed to the stream, up to a maximum of 1 second.
        let start = Date()
        while continuations.isEmpty {
            if Date().timeIntervalSince(start) > 1.0 {
                break
            }
            await Task.yield()
        }
        for continuation in continuations.values {
            continuation.yield()
        }
    }
    
    func stop() { 
        stopCalled = true
        isStarted = false
    }
}

@Suite("Counter Domain Tests", .serialized)
struct CounterTests {
    
    @MainActor
    @Test("Incrementing the counter increases the count by 1")
    func increment() async {
        let store = TestStore(initialState: CounterState(), flow: createCounterFlow(clock: ImmediateClock()))
        await store.send(.increment) {
            $0.count = 1
        }
    }

    @MainActor
    @Test("Decrementing the counter decreases the count by 1")
    func decrement() async {
        let store = TestStore(initialState: CounterState(), flow: createCounterFlow(clock: ImmediateClock()))
        await store.send(.decrement) {
            $0.count = -1
        }
    }

    @MainActor
    @Test("A delayed increment action should set isProcessing to true")
    func delayedIncrement() async {
        let store = TestStore(initialState: CounterState(), flow: createCounterFlow(clock: ImmediateClock()))
        
        await store.send(.delayedIncrement) {
            $0.isProcessing = true
        }
        
        await store.receive(.increment) {
            $0.isProcessing = false
            $0.count = 1
        }
    }

    @MainActor
    @Test("Resetting the counter sets count to 0 and waits for a new reset signal")
    func reset() async {
        let store = TestStore(initialState: CounterState(count: 10), flow: createCounterFlow(clock: ImmediateClock()))
        
        await store.send(.reset) {
            $0.count = 0
        }
        
        // Assert the silent effect finishes (waiting for next signal)
        // Wait, .reset triggers .waitForResetSignal() which has an ID but is infinite.
        // We'd need to stop monitoring to clean up.
        await store.send(.stopMonitoring)
        await store.receiveNoAction()
    }

    @MainActor
    @Test("Starting monitoring starts the service and begins waiting for signals")
    func startMonitoring() async {
        let mock = MockCounterResetService()
        Current.counterResetService = mock
        
        let store = TestStore(initialState: CounterState(count: 10), flow: createCounterFlow(clock: ImmediateClock()))
        
        // 1. Start monitoring. The background task will subscribe to the stream.
        await store.send(.startMonitoring)
        
        // 2. We can perform other actions while monitoring is active
        await store.send(.increment) {
            $0.count = 11
        }
        
        // 3 & 4. Emit the signal and seamlessly receive the resulting action!
        await store.receive(.reset, triggering: {
            await mock.emitReset()
        }) {
            $0.count = 0
        }
        
        // 5. If we received the action, the effect must have started successfully.
        #expect(mock.startCalled == true)
        
        // 6. Stop monitoring to cancel the infinite listener task
        await store.send(.stopMonitoring)
        
        // 7. Ensure the cancellation task finishes
        await store.receiveNoAction()
        
        // 8. Now we can safely assert it was stopped
        #expect(mock.stopCalled == true)
        
        // Verify when a new reset signal is sent, the flow is not affected.
        await mock.emitReset()
    }
}
