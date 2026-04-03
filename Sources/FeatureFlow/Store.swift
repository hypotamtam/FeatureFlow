import Foundation
import SwiftUI

public final class Store<State: FeatureFlow.State, Action: Sendable>: @unchecked Sendable {
    
    private let lock = RecursiveLock()
    
    // Internal state storage to ensure atomic updates with flow execution
    private var _state: State
    private var continuations: [UUID: AsyncStream<State>.Continuation] = [:]
    private var streamTask: Task<Void, Never>?
    
    public var state: State {
        lock.lock(); defer { lock.unlock() }
        return _state
    }
    
    public var stateStream: AsyncStream<State> {
        AsyncStream { continuation in
            let id = UUID()
            
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.removeContinuation(id: id)
            }

            lock.lock()
            defer { lock.unlock() }
            
            continuations[id] = continuation
            continuation.yield(_state)
        }
    }
    
    private let flow: Flow<State, Action>?
    private let onAction: (@Sendable (Action) -> Void)?
    
    private var tasks: [AnyHashable: (task: Task<Void, Never>, id: UUID)] = [:]
    
    public init(initialState: State, flow: Flow<State, Action>) {
        self._state = initialState
        self.flow = flow
        self.onAction = nil
    }
    
    private init<S: AsyncSequence & Sendable>(
        initialState: State,
        onAction: @escaping @Sendable (Action) -> Void,
        stream: S
    ) where S.Element == State {
        self._state = initialState
        self.flow = nil
        self.onAction = onAction
        
        self.streamTask = Task { [weak self] in
            do {
                for try await newState in stream {
                    self?.updateState(newState)
                }
            } catch {
                // Should not happen for our stream types
            }
        }
    }
    
    deinit {
        streamTask?.cancel()
    }
    
    private func removeContinuation(id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
    
    private func updateState(_ newState: State) {
        lock.lock()
        defer { lock.unlock() }
        if _state != newState {
            _state = newState
            notifyObservers(of: newState)
        }
    }
    
    private func notifyObservers(of newState: State) {
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }
    
    public func send(_ action: Action) {
        if let flow = flow {
            lock.lock()
            let oldState = _state
            let result = flow.run(_state, action)
            _state = result.state
            let effects = result.effects
            
            if oldState != result.state {
                notifyObservers(of: result.state)
            }
            
            for effect in effects {
                execute(effect)
            }
            
            lock.unlock()
        } else if let onAction = onAction {
            onAction(action)
        }
    }

    private func execute(_ effect: Effect<Action>) {
        lock.lock()
        if let id = effect.id {
            if effect.policy == .cancelPrevious {
                tasks[id]?.task.cancel()
            } else if effect.policy == .runIfMissing, tasks[id] != nil {
                lock.unlock()
                return
            }
        }

        let executionID = UUID()
        let task = Task { [weak self] in
            let nextAction = await effect.operation()
            
            guard let self = self else { return }

            if let id = effect.id {
                self.lock.lock()
                if self.tasks[id]?.id == executionID {
                    self.tasks[id] = nil
                }
                self.lock.unlock()
            }

            if !Task.isCancelled, let nextAction = nextAction {
                self.send(nextAction)
            }
        }

        if let id = effect.id {
            tasks[id] = (task, executionID)
        }
        lock.unlock()
    }
    
    public func scope<ChildState: FeatureFlow.State, ChildAction: Sendable>(
        state childKeyPath: KeyPath<State, ChildState> & Sendable,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> Store<ChildState, ChildAction> {
        let mappedStream = self.stateStream.map { state in
            state[keyPath: childKeyPath]
        }
        
        return Store<ChildState, ChildAction>(
            initialState: state[keyPath: childKeyPath],
            onAction: { [weak self] childAction in
                self?.send(fromChildAction(childAction))
            },
            stream: mappedStream
        )
    }
}

/// A thread-safe recursive lock wrapper.
private final class RecursiveLock: @unchecked Sendable {
    private let _lock = NSRecursiveLock()
    
    func lock() {
        _lock.lock()
    }
    
    func unlock() {
        _lock.unlock()
    }
}
