import Foundation

/// Defines how an effect should behave when another effect with the same ID is already running.
public enum EffectPolicy: Sendable {
    /// Cancels any existing effect with the same ID before starting. (Standard for Debounce)
    case cancelPrevious
    /// If an effect with the same ID is already running, the new one is ignored. (Standard for Throttle/Ignore)
    case runIfMissing
}

/// A wrapper around an asynchronous operation that can optionally emit an action back into the system.
///
/// `Effect`s are returned by `Flow`s to perform side effects like network requests, timers, or database writes
/// without violating the pure nature of the flow logic.
public struct Effect<Action: Sendable>: @unchecked Sendable {
    /// A type used to uniquely identify an effect for cancellation or throttling.
    public typealias ID = AnyHashable
    /// The asynchronous closure that performs the work and optionally returns a new action.
    public typealias Operation = @Sendable () async -> Action?
    
    /// The unique identifier of the effect, used for managing policies.
    public let id: ID?
    /// The policy dictating how to handle execution if an effect with the same ID is already running.
    public let policy: EffectPolicy
    package let operation: Operation
    
    /// Creates a new effect.
    ///
    /// - Parameters:
    ///   - id: An optional unique identifier for the effect.
    ///   - policy: The policy to apply if an effect with this ID is already running. Defaults to `.cancelPrevious`.
    ///   - operation: The asynchronous work to perform.
    public init(
        id: ID? = nil,
        policy: EffectPolicy = .cancelPrevious,
        operation: @escaping Operation = { nil }
    ) {
        self.id = id
        self.policy = policy
        self.operation = operation
    }
    
    /// Transforms the action emitted by this effect into a new action type.
    func map<OtherAction: Sendable>(transform: @escaping @Sendable (Action) -> OtherAction) -> Effect<OtherAction> {
        Effect<OtherAction>(id: id, policy: policy) {
            let resultAction = await self.operation()
            return resultAction.map { transform($0) }
        }
    }

    /// Creates an effect that immediately cancels any running effect with the given ID.
    public static func cancel(id: ID) -> Effect {
        Effect(id: id, policy: .cancelPrevious)
    }

    /// Creates an effect that waits for a time interval (in seconds) before executing.
    ///
    /// This is compatible with older OS versions (iOS 13+, macOS 10.15+).
    /// If called multiple times with the same ID, previous calls are cancelled.
    public static func debounce(
        id: ID,
        for interval: TimeInterval,
        operation: @escaping Operation
    ) -> Effect {
        Effect(id: id, policy: .cancelPrevious) {
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
                return await operation()
            } catch {
                return nil
            }
        }
    }

    /// Creates an effect that waits for a duration before executing using a specific clock.
    ///
    /// By default, it uses the ContinuousClock. If called multiple times with the same ID, 
    /// previous calls are cancelled.
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
    ///
    /// This is compatible with older OS versions (iOS 13+, macOS 10.15+).
    public static func throttle(
        id: ID,
        for interval: TimeInterval,
        operation: @escaping Operation
    ) -> Effect {
        Effect(id: id, policy: .runIfMissing) {
            do {
                let result = await operation()
                try await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
                return result
            } catch {
                return nil
            }
        }
    }

    /// Creates an effect that will be ignored if an effect with the same ID is already running, 
    /// using a specific clock to unlock the ID after a duration passes.
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
