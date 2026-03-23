import Foundation
import Combine
import SwiftUI

public final class Store<State: FeatureFlow.State, Action: Sendable>: @unchecked Sendable {
    
    private let stateSubject: CurrentValueSubject<State, Never>
    private let lock = RecursiveLock()
    
    // Internal state storage to ensure atomic updates with flow execution
    private var _state: State
    
    public var state: State {
        lock.lock(); defer { lock.unlock() }
        return _state
    }
    
    public var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    public var stateStream: AsyncStream<State> {
        AsyncStream { continuation in
            let cancellable = SendableCancellable(stateSubject
                .sink { continuation.yield($0) })
            
            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }
    
    private let flow: Flow<State, Action>?
    private let onAction: (@Sendable (Action) -> Void)?
    
    private var tasks: [AnyHashable: (task: Task<Void, Never>, id: UUID)] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    public init(initialState: State, flow: Flow<State, Action>) {
        self._state = initialState
        self.stateSubject = CurrentValueSubject(initialState)
        self.flow = flow
        self.onAction = nil
    }
    
    private init(
        initialState: State,
        onAction: @escaping @Sendable (Action) -> Void,
        publisher: AnyPublisher<State, Never>
    ) {
        self._state = initialState
        self.stateSubject = CurrentValueSubject(initialState)
        self.flow = nil
        self.onAction = onAction
        
        publisher
            .sink { [weak self] newState in
                self?.updateState(newState)
            }
            .store(in: &cancellables)
    }
    
    private func updateState(_ newState: State) {
        lock.lock()
        _state = newState
        sendUpdate(newState)
        lock.unlock()
    }
    
    private func sendUpdate(_ newState: State) {
        guard stateSubject.value != newState else {
            return
        }
        stateSubject.send(newState)
    }
    
    public func send(_ action: Action) {
        if let flow = flow {
            lock.lock()
            let result = flow.run(_state, action)
            _state = result.state
            let effects = result.effects
            
            // Notify observers while holding the lock to ensure state synchronization 
            // and avoid race conditions where multiple threads call sendUpdate out of order.
            // NSRecursiveLock allows this even if subscribers call send synchronously.
            sendUpdate(result.state)
            
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
        state childKeyPath: KeyPath<State, ChildState>,
        action fromChildAction: @escaping @Sendable (ChildAction) -> Action
    ) -> Store<ChildState, ChildAction> {
        Store<ChildState, ChildAction>(
            initialState: state[keyPath: childKeyPath],
            onAction: { [weak self] childAction in
                self?.send(fromChildAction(childAction))
            },
            publisher: stateSubject
                .map(childKeyPath)
                .eraseToAnyPublisher()
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

private final class SendableCancellable: @unchecked Sendable {
    private let cancellable: AnyCancellable
    init(_ cancellable: AnyCancellable) {
        self.cancellable = cancellable
    }
    func cancel() {
        cancellable.cancel()
    }
}
