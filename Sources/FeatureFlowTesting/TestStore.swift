import Foundation
import FeatureFlow
import Testing

/// A test store built specifically to execute `Flow` logic deterministically
/// and rigorously assert state mutations and effect outputs.
@MainActor
public final class TestStore<State: FeatureFlow.State & Equatable, Action: FeatureFlow.Action & Equatable> {
    
    public private(set) var state: State
    private let flow: Flow<State, Action>
    
    // Tracks active effects by their ID to support cancellation and exhaustivity checks.
    private var tasks: [AnyHashable: Task<Action?, Never>] = [:]
    // Tracks actions emitted by effects that haven't been asserted yet.
    private var receivedActions: [Action] = []
    
    /// Creates a TestStore that intercepts effects and asserts step-by-step execution.
    public init(initialState: State, flow: Flow<State, Action>) {
        self.state = initialState
        self.flow = flow
    }
    
    deinit {
        // Exhaustivity check: The test fails if effects or actions are left unhandled!
        MainActor.assumeIsolated {
            let taskCount = tasks.count
            let actionCount = receivedActions.count
            
            if taskCount > 0 || actionCount > 0 {
                let message: String = """
                TestStore deallocated with unhandled work:
                - Active effects: \(taskCount)
                - Unhandled actions in queue: \(actionCount)
                
                Use .receive() or .receiveNoAction() to assert them before the test ends.
                """
                Issue.record(Comment(stringLiteral: message))
            }
        }
    }
    
    private func assertEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        message: String,
        sourceLocation: SourceLocation
    ) {
        if actual != expected {
            let errorMessage = """
            \(message) 
            Expected: \(expected)
            Actual: \(actual)
            """
            Issue.record(Comment(stringLiteral: errorMessage), sourceLocation: sourceLocation)
        }
    }
    
    private func processEffects(_ effects: [Effect<Action>]) {
        for effect in effects {
            // Support cancellation policies
            if let id = effect.id {
                if effect.policy == .cancelPrevious {
                    tasks[id]?.cancel()
                    tasks.removeValue(forKey: id)
                } else if effect.policy == .runIfMissing, tasks[id] != nil {
                    continue
                }
            }

            let taskID = effect.id ?? AnyHashable(UUID())
            let task = Task { [weak self] in
                let action = await effect.operation()

                guard let self = self else { return action }
                
                if let action = action, !Task.isCancelled {
                    self.receivedActions.append(action)
                }
                
                // Cleanup the task from tracking once it finishes execution
                self.tasks.removeValue(forKey: taskID)

                return action
            }

            tasks[taskID] = task
        }
    }
    
    /// Sends an action into the store and asserts the resulting state mutation.
    ///
    /// - Parameters:
    ///   - action: The action to send.
    ///   - sourceLocation: The source location where this assertion is made.
    ///   - expectedState: A closure that mutates the expected state.
    public func send(
        _ action: Action,
        sourceLocation: SourceLocation = #_sourceLocation,
        expectedState: ((inout State) -> Void)? = nil
    ) async {
        if !receivedActions.isEmpty {
            Issue.record("Cannot send an action when there are unhandled received actions in the queue. Assert them first using .receive().", sourceLocation: sourceLocation)
            return
        }
        
        let result = flow.run(state, action)
        
        var expected = state
        expectedState?(&expected)
        
        assertEqual(result.state, expected, message: "State mutation did not match expectation.", sourceLocation: sourceLocation)
        self.state = result.state
        
        processEffects(result.effects)
    }
    
    /// Waits for the next background effect to emit an action, and asserts its state mutation.
    ///
    /// - Parameters:
    ///   - expectedAction: The action you expect the background effect to emit.
    ///   - timeout: The maximum time to wait for an action to be emitted. Defaults to 1 second.
    ///   - sourceLocation: The source location where this assertion is made.
    ///   - expectedState: A closure that mutates the expected state resulting from the received action.
    public func receive(
        _ expectedAction: Action,
        timeout: TimeInterval = 1.0,
        sourceLocation: SourceLocation = #_sourceLocation,
        expectedState: ((inout State) -> Void)? = nil
    ) async {
        let start = Date()
        
        while receivedActions.isEmpty {
            if Date().timeIntervalSince(start) > timeout {
                Issue.record("Expected to receive action \(expectedAction), but timed out after \(timeout) seconds.", sourceLocation: sourceLocation)
                return
            }
            await Task.yield()
        }
        
        let actualAction = receivedActions.removeFirst()
        assertEqual(actualAction, expectedAction, message: "Received action did not match expected action.", sourceLocation: sourceLocation)
        
        let result = flow.run(state, actualAction)
        
        var expected = state
        expectedState?(&expected)
        
        assertEqual(result.state, expected, message: "State mutation from received action did not match expectation.", sourceLocation: sourceLocation)
        self.state = result.state
        
        processEffects(result.effects)
        
        // Give background tasks a chance to start
        await Task.yield()
    }

    /// Waits for the next background effect to emit an action while concurrently executing a trigger,
    /// and asserts its state mutation.
    ///
    /// This is especially useful for testing effects that listen to long-living streams
    /// (like `AsyncStream` or `NotificationCenter`), where you need to trigger a value
    /// externally without blocking the test's ability to receive the resulting action.
    ///
    /// - Parameters:
    ///   - expectedAction: The action you expect the background effect to emit.
    ///   - timeout: The maximum time to wait for an action to be emitted. Defaults to 1 second.
    ///   - triggering: An async closure that triggers the expected action (e.g., emitting a stream value).
    ///   - sourceLocation: The source location where this assertion is made.
    ///   - expectedState: A closure that mutates the expected state resulting from the received action.
    public func receive(
        _ expectedAction: Action,
        timeout: TimeInterval = 1.0,
        triggering: @escaping @Sendable () async -> Void,
        sourceLocation: SourceLocation = #_sourceLocation,
        expectedState: ((inout State) -> Void)? = nil
    ) async {
        // 1. Fire the trigger concurrently so it doesn't block the receive loop
        let triggerTask = Task {
            await triggering()
        }
        
        // 2. Wait for the action and assert the state (using the existing method)
        await self.receive(
            expectedAction,
            timeout: timeout,
            sourceLocation: sourceLocation,
            expectedState: expectedState
        )
        
        // 3. Ensure the trigger task finishes cleanly
        await triggerTask.value
    }

    /// Asserts that all pending effects have finished without emitting any actions.
    ///
    /// This is useful for verifying cancellation effects or effects that only perform
    /// side-work without updating the state.
    public func receiveNoAction(
        timeout: TimeInterval = 1.0,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        if !receivedActions.isEmpty {
            let next = receivedActions.first!
            Issue.record("Cannot call receiveNoAction when there are unhandled received actions in the queue: \(next). Assert them first using .receive().", sourceLocation: sourceLocation)
            return
        }

        let start = Date()
        
        // Wait for all current and recursive tasks to reach a terminal state.
        while !tasks.isEmpty {
            if Date().timeIntervalSince(start) > timeout {
                Issue.record("Timed out waiting for effects to finish in receiveNoAction after \(timeout) seconds. Still have \(tasks.count) active tasks.", sourceLocation: sourceLocation)
                return
            }
            
            // We take a snapshot of the current tasks and wait for them.
            let currentTasks = Array(tasks.values)
            for task in currentTasks {
                _ = await task.result
            }
            
            await Task.yield()
        }
        
        if !receivedActions.isEmpty {
            let next = receivedActions.first!
            Issue.record("Expected no action to be received, but found unhandled action in queue: \(next)", sourceLocation: sourceLocation)
        }
    }
}
