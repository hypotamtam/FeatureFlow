import Foundation

/// A global service that emits reset signals at random intervals.
@MainActor
public final class CounterResetService: CounterResetServiceProtocol {
    public static let shared = CounterResetService()
    
    private var task: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    
    public var isStarted: Bool {
        task != nil
    }
    
    public var resetNotificationEmitter: AsyncStream<Void> {
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
    
    private init() {}
    
    public func start() {
        stop()
        task = Task {
            while !Task.isCancelled {
                let delay = Double.random(in: 3...10)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { break }
                
                for continuation in continuations.values {
                    continuation.yield()
                }
            }
        }
    }
    
    public func stop() {
        task?.cancel()
        task = nil
    }
}
