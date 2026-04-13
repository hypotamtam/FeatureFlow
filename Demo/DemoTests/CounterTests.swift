import Testing
import Foundation
import FeatureFlow
import FeatureFlowTesting
@testable import Demo

@MainActor
final class MockCounterResetService: CounterResetServiceProtocol {
    var startCalled = false
    var stopCalled = false
    
    private var _isStarted = false
    private var isStartedContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    
    var isStarted: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.isStartedContinuations[id] = nil
                }
            }
            self.isStartedContinuations[id] = continuation
            continuation.yield(self._isStarted)
        }
    }
    
    private(set) var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    
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
        _isStarted = true
        for continuation in isStartedContinuations.values {
            continuation.yield(true)
        }
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
        _isStarted = false
        for continuation in isStartedContinuations.values {
            continuation.yield(false)
        }
    }
}

@Suite("Counter Domain Tests", .serialized)
struct CounterTests {
    
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test("Incrementing the counter increases the count by 1")
    func increment() async {
        let store = TestStore(initialState: CounterState(), flow: createCounterFlow(clock: ImmediateClock()))
        await store.send(.increment) {
            $0.count = 1
        }
    }

    @MainActor
    @Test("Incrementing the legacy counter increases the count by 1")
    func incrementLegacy() async throws {
        // Legacy flow doesn't use dependency injection for clocks, so we use the raw Store.
        let store = Store(initialState: CounterState(), flow: counterFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.increment)
        
        let state = await iterator.next()
        #expect(state?.count == 1)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test("Decrementing the counter decreases the count by 1")
    func decrement() async {
        let store = TestStore(initialState: CounterState(), flow: createCounterFlow(clock: ImmediateClock()))
        await store.send(.decrement) {
            $0.count = -1
        }
    }

    @MainActor
    @Test("Decrementing the legacy counter decreases the count by 1")
    func decrementLegacy() async throws {
        let store = Store(initialState: CounterState(), flow: counterFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.decrement)
        
        let state = await iterator.next()
        #expect(state?.count == -1)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
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
    @Test("A legacy delayed increment action should set isProcessing to true")
    func delayedIncrementLegacy() async throws {
        let store = Store(initialState: CounterState(), flow: counterFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.delayedIncrement)
        
        let processingState = await iterator.next()
        #expect(processingState?.isProcessing == true)
        
        // Wait 1 second for the sleep to finish
        let finalState = await iterator.next()
        #expect(finalState?.count == 1)
        #expect(finalState?.isProcessing == false)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
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
    @Test("Resetting the legacy counter sets count to 0 and waits for a new reset signal")
    func resetLegacy() async throws {
        let store = Store(initialState: CounterState(count: 10), flow: counterFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.reset)
        
        let resetState = await iterator.next()
        #expect(resetState?.count == 0)
        
        // Stop monitoring to clean up the infinite effect in the background
        store.send(.stopMonitoring)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
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

    @MainActor
    @Test("Starting monitoring on legacy starts the service and begins waiting for signals")
    func startMonitoringLegacy() async throws {
        let mock = MockCounterResetService()
        var isStartedIterator = mock.isStarted.dropFirst().makeAsyncIterator()
        Current.counterResetService = mock
        
        let store = Store(initialState: CounterState(count: 10), flow: counterFlowLegacy)
        var stateIterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.startMonitoring)
        var isStarted = await isStartedIterator.next()
        #expect(isStarted == true)
        #expect(mock.startCalled == true)
        
        // Wait for the effect to attach to the stream
        var attempts = 0
        while mock.continuations.isEmpty && attempts < 100 {
            await Task.yield()
            attempts += 1
        }
        
        await mock.emitReset()
        
        
        let notificationResetState = await stateIterator.next()
        #expect(notificationResetState?.count == 0)
        
        store.send(.stopMonitoring)
        
        isStarted = await isStartedIterator.next()
        #expect(isStarted == false)
        #expect(mock.stopCalled == true)
    }
}
