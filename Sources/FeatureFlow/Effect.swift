import Foundation

public enum EffectPolicy {
    /// Cancels any existing effect with the same ID before starting. (Standard for Debounce)
    case cancelPrevious
    /// If an effect with the same ID is already running, the new one is ignored. (Standard for Throttle/Ignore)
    case runIfMissing
}

public struct Effect<Action> {
    public let id: AnyHashable?
    public let policy: EffectPolicy
    let operation: () async -> Action?
    
    public init(
        id: AnyHashable? = nil,
        policy: EffectPolicy = .cancelPrevious,
        operation: @escaping () async -> Action?
    ) {
        self.id = id
        self.policy = policy
        self.operation = operation
    }
    
    func map<OtherAction>(transform: @escaping (Action) -> OtherAction) -> Effect<OtherAction> {
        Effect<OtherAction>(id: id, policy: policy) {
            let resultAction = await self.operation()
            return resultAction.map { transform($0) }
        }
    }

    /// Creates an effect that cancels any running effect with the given ID.
    public static func cancel(id: AnyHashable) -> Effect {
        Effect(id: id, policy: .cancelPrevious) { nil }
    }

    /// Creates an effect that waits for a duration before executing.
    /// If a new effect with the same ID is sent before the duration expires, the previous one is cancelled.
    public static func debounce(
        id: AnyHashable,
        for seconds: TimeInterval,
        operation: @escaping () async -> Action?
    ) -> Effect {
        Effect(id: id, policy: .cancelPrevious) {
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return await operation()
            } catch {
                // Task was cancelled during sleep
                return nil
            }
        }
    }

    /// Creates an effect that will be ignored if an effect with the same ID is already running.
    public static func throttle(
        id: AnyHashable,
        operation: @escaping () async -> Action?
    ) -> Effect {
        Effect(id: id, policy: .runIfMissing, operation: operation)
    }
}
