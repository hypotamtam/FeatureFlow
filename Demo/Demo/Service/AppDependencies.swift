import Foundation

// MARK: - Protocols

public protocol UserServiceProtocol {
    func fetchUser() async throws -> String
}

public protocol CounterResetServiceProtocol {
    func start()
    func stop()
}

// MARK: - Dependency Container

public struct Dependencies {
    public var userService: UserServiceProtocol
    public var counterResetService: CounterResetServiceProtocol
}

// Global environment holder
public var Current = Dependencies(
    userService: UserService.shared,
    counterResetService: CounterResetService.shared
)
