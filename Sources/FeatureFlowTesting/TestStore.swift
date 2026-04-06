import Foundation
import FeatureFlow

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
            if !tasks.isEmpty || !receivedActions.isEmpty {
                fatalError("TestStore deallocated with unhandled effects (\(tasks.count)) or received actions (\(receivedActions.count)). Use .receive() or .receiveNoAction() to assert them.")
            }
        }
    }
    
    private func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, message: String, file: StaticString = #file, line: UInt = #line) {
        if lhs != rhs {
            let errorMessage = "\(message) Expected: \(rhs), Actual: \(lhs)"
            fatalError(errorMessage, file: file, line: line)
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

                if let action = action, !Task.isCancelled {
                    await MainActor.run {
                        self?.receivedActions.append(action)
                    }
                }
                
                // Cleanup the task from tracking once it finishes execution
                await MainActor.run {
                    self?.tasks.removeValue(forKey: taskID)
                }

                return action
            }

            tasks[taskID] = task
        }
    }
    
    /// Sends an action into the store and asserts the resulting state mutation.
    ///
    /// - Parameters:
    ///   - action: The action to send.
    ///   - file: The file where this assertion is made.
    ///   - line: The line where this assertion is made.
    ///   - expectedState: A closure that mutates the expected state. 
    public func send(
        _ action: Action,
        file: StaticString = #file,
        line: UInt = #line,
        expectedState: ((inout State) -> Void)? = nil
    ) async {
        if !receivedActions.isEmpty {
            fatalError("Cannot send an action when there are unhandled received actions in the queue. Assert them first using .receive().", file: file, line: line)
        }
        
        let result = flow.run(state, action)
        
        var expected = state
        expectedState?(&expected)
        
        assertEqual(result.state, expected, message: "State mutation did not match expectation.", file: file, line: line)
        self.state = result.state
        
        processEffects(result.effects)
        
        // Give background tasks a chance to start
        await Task.yield()
    }
    
    /// Waits for the next background effect to emit an action, and asserts its state mutation.
    ///
    /// - Parameters:
    ///   - expectedAction: The action you expect the background effect to emit.
    ///   - timeout: The maximum time to wait for an action to be emitted. Defaults to 1 second.
    ///   - file: The file where this assertion is made.
    ///   - line: The line where this assertion is made.
    ///   - expectedState: A closure that mutates the expected state resulting from the received action.
    public func receive(
        _ expectedAction: Action,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line,
        expectedState: ((inout State) -> Void)? = nil
    ) async {
        let start = Date()
        
        while receivedActions.isEmpty {
            if Date().timeIntervalSince(start) > timeout {
                fatalError("Expected to receive action \(expectedAction), but timed out after \(timeout) seconds.", file: file, line: line)
            }
            await Task.yield()
        }
        
        let actualAction = receivedActions.removeFirst()
        assertEqual(actualAction, expectedAction, message: "Received action did not match expected action.", file: file, line: line)
        
        let result = flow.run(state, actualAction)
        
        var expected = state
        expectedState?(&expected)
        
        assertEqual(result.state, expected, message: "State mutation from received action did not match expectation.", file: file, line: line)
        self.state = result.state
        
        processEffects(result.effects)
        
        // Give background tasks a chance to start
        await Task.yield()
    }

    /// Asserts that all pending effects have finished without emitting any actions.
    ///
    /// This is useful for verifying cancellation effects or effects that only perform
    /// side-work without updating the state.
    public func receiveNoAction(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        if !receivedActions.isEmpty {
            let next = receivedActions.first!
            fatalError("Cannot call receiveNoAction when there are unhandled received actions in the queue: \(next). Assert them first using .receive().", file: file, line: line)
        }

        let start = Date()
        
        // Wait for all current and recursive tasks to reach a terminal state.
        while !tasks.isEmpty {
            if Date().timeIntervalSince(start) > timeout {
                fatalError("Timed out waiting for effects to finish in receiveNoAction after \(timeout) seconds. Still have \(tasks.count) active tasks.", file: file, line: line)
            }
            
            // We take a snapshot of the current tasks and wait for them.
            // Since tasks remove themselves from the dictionary upon finishing,
            // we will eventually exit the loop.
            let currentTasks = Array(tasks.values)
            for task in currentTasks {
                _ = await task.result
            }
            
            await Task.yield()
        }
        
        if !receivedActions.isEmpty {
            let next = receivedActions.first!
            fatalError("Expected no action to be received, but found unhandled action in queue: \(next)", file: file, line: line)
        }
    }
}
