import Foundation

/// A global service that emits reset signals at random intervals.
public final class CounterResetService: CounterResetServiceProtocol {
    public static let shared = CounterResetService()
    
    private var task: Task<Void, Never>?
    
    private init() {}
    
    public func start() {
        stop()
        task = Task {
            while !Task.isCancelled {
                let delay = Double.random(in: 3...10)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { break }
                NotificationCenter.default.post(name: .resetCounterSignal, object: nil)
            }
        }
    }
    
    public func stop() {
        task?.cancel()
        task = nil
    }
}
