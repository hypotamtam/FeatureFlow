import Foundation

/// A service responsible for fetching user data.
public struct UserService: UserServiceProtocol {
    public static let shared = UserService()
    
    public init() {}
    
    public func fetchUser() async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Simulate success or failure
        if Bool.random() {
            return "Jane Doe"
        } else {
            throw NSError(
                domain: "UserService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Network connection lost"]
            )
        }
    }
}
