import Foundation

/// A type that represents the state of a feature.
///
/// State must be `Equatable` to allow for efficient view updates and testing assertions.
/// It must also be `Sendable` to safely cross actor boundaries during asynchronous updates.
public protocol State: Equatable, Sendable {}

public extension State {
    /// Creates a copy of the state, applies the given updates, and returns the modified copy.
    ///
    /// This is a convenience method for applying mutations in a pure, functional way within a `Flow`.
    ///
    /// - Parameter updates: A closure that performs mutations on the inout copy of the state.
    /// - Returns: A new state instance with the applied updates.
    func with(_ updates: (inout Self) -> Void) -> Self {
        var copy = self
        updates(&copy)
        return copy
    }
}


/// A type that represents an action or event in a feature.
///
/// Actions are typically enums that describe everything a user can do (e.g., `incrementTapped`)
/// and all events that can happen externally (e.g., `apiResponseReceived`).
/// Actions must be `Sendable` to be safely passed between asynchronous effects and the main flow.
public protocol Action: Sendable {}
