import Foundation

public enum EffectPolicy: Sendable {
    /// Cancels any existing effect with the same ID before starting. (Standard for Debounce)
    case cancelPrevious
    /// If an effect with the same ID is already running, the new one is ignored. (Standard for Throttle/Ignore)
    case runIfMissing
}

public struct Effect<Action: Sendable>: @unchecked Sendable {
    public typealias ID = AnyHashable
    public typealias Operation = @Sendable () async -> Action?
    
    
    public let id: ID?
    public let policy: EffectPolicy
    package let operation: Operation
    
    public init(
        id: ID? = nil,
        policy: EffectPolicy = .cancelPrevious,
        operation: @escaping Operation = { nil }
    ) {
        self.id = id
        self.policy = policy
        self.operation = operation
    }
    
    func map<OtherAction: Sendable>(transform: @escaping @Sendable (Action) -> OtherAction) -> Effect<OtherAction> {
        Effect<OtherAction>(id: id, policy: policy) {
            let resultAction = await self.operation()
            return resultAction.map { transform($0) }
        }
    }

    /// Creates an effect that cancels any running effect with the given ID.
    public static func cancel(id: ID) -> Effect {
        Effect(id: id, policy: .cancelPrevious)
    }

    /// Creates an effect that waits for a time interval (in seconds) before executing.
    /// This is compatible with older OS versions (iOS 13+, macOS 10.15+).
    public static func debounce(
        id: ID,
        for interval: TimeInterval,
        operation: @escaping Operation
    ) -> Effect {
        Effect(id: id, policy: .cancelPrevious) {
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                return await operation()
            } catch {
                return nil
            }
        }
    }

    /// Creates an effect that waits for a duration before executing using a specific clock.
    /// By default, it uses the ContinuousClock.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public static func debounce(
        id: ID,
        for duration: Duration,
        clock: any Clock<Duration> = ContinuousClock(),
        operation: @escaping Operation
    ) -> Effect {
        Effect(id: id, policy: .cancelPrevious) {
            do {
                try await clock.sleep(for: duration)
                return await operation()
            } catch {
                return nil
            }
        }
    }

    /// Creates an effect that will be ignored if an effect with the same ID is already running.
    public static func throttle(id: ID, operation: @escaping Operation) -> Effect {
        Effect(id: id, policy: .runIfMissing, operation: operation)
    }

    /// Creates an effect that will be ignored if an effect with the same ID is already running, 
    /// unlocking the ID only after a time interval (in seconds) passes.
    /// This is compatible with older OS versions (iOS 13+, macOS 10.15+).
    public static func throttle(
        id: ID,
        for interval: TimeInterval,
        operation: @escaping Operation
    ) -> Effect {
        Effect(id: id, policy: .runIfMissing) {
            do {
                let result = await operation()
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                return result
            } catch {
                return nil
            }
        }
    }

    /// Creates an effect that will be ignored if an effect with the same ID is already running, using a specific clock.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public static func throttle(
        id: ID,
        for duration: Duration,
        clock: any Clock<Duration> = ContinuousClock(),
        operation: @escaping Operation
    ) -> Effect {
        Effect(id: id, policy: .runIfMissing) {
            do {
                let result = await operation()
                try await clock.sleep(for: duration)
                return result
            } catch {
                return nil
            }
        }
    }
}
