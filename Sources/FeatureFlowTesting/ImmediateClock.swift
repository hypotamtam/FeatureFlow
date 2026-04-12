import Foundation

/// A clock that does not delay execution when `sleep` is called.
///
/// This clock is ideal for unit tests where you want asynchronous effects
/// that use `Task.sleep` to execute instantly without blocking the test.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct ImmediateClock: Clock, Sendable {
    public struct Instant: InstantProtocol {
        public func advanced(by duration: Duration) -> ImmediateClock.Instant {
            self
        }

        public func duration(to other: ImmediateClock.Instant) -> Duration {
            .zero
        }
        
        public static func < (lhs: ImmediateClock.Instant, rhs: ImmediateClock.Instant) -> Bool {
            false
        }
    }

    public init() {}

    public var now: Instant {
        Instant()
    }

    public var minimumResolution: Duration {
        .zero
    }

    /// Does not suspend. Returns immediately.
    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        // No-op
        try Task.checkCancellation()
    }
}
