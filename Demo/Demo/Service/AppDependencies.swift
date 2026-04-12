import Foundation

// MARK: - Protocols

public protocol UserServiceProtocol: Sendable {
    func fetchUser() async throws -> String
}


public protocol CounterResetServiceProtocol: Sendable {    
    func start()
    func stop()
    
    var resetNotificationEmitter: AsyncStream<Void> { get }
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
