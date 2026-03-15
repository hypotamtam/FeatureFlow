import Foundation

// MARK: - Protocols

public protocol UserServiceProtocol: Sendable {
    func fetchUser() async throws -> String
}

// Mark the service protocol as @MainActor. 
// Since it inherits from Sendable, any @MainActor class or actor will conform.
@MainActor
public protocol CounterResetServiceProtocol: Sendable {
    func start()
    func stop()
}

// MARK: - Dependency Container

public struct Dependencies: Sendable {
    public var userService: UserServiceProtocol
    public var counterResetService: CounterResetServiceProtocol
}

// Global environment holder isolated to MainActor
@MainActor
public var Current = Dependencies(
    userService: UserService.shared,
    counterResetService: CounterResetService.shared
)
