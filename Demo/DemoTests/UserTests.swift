import Testing
import Foundation
@testable import FeatureFlow
@testable import Demo

struct MockUserService: UserServiceProtocol {
    var result: Result<String, Error>
    
    func fetchUser() async throws -> String {
        try result.get()
    }
}

@Suite("User Domain Tests")
struct UserTests {
    
    @Test("The initial state should have the correct default values")
    func initialState() {
        let state = UserState()
        #expect(state.name == "Unknown User")
        #expect(state.isLoading == false)
        #expect(state.error == nil)
    }

    @Test("Initiating a user fetch request should set isLoading to true")
    func fetchRequest() {
        var state = UserState()
        state.error = "Previous connection error"
        
        let result = userFlow.run(state, .fetchRequest)
        
        #expect(result.state.isLoading == true)
        #expect(result.state.error == nil)
        #expect(result.effects.count == 1)
    }

    @Test("A successful user fetch should update the name")
    func fetchSuccess() {
        var state = UserState()
        state.isLoading = true
        
        let result = userFlow.run(state, .fetchSuccess("Jane Doe"))
        
        #expect(result.state.name == "Jane Doe")
        #expect(result.state.isLoading == false)
    }

    @Test("A failed user fetch should capture the error message")
    func fetchFailure() {
        var state = UserState()
        state.isLoading = true
        
        let errorMessage = "Access Denied"
        let result = userFlow.run(state, .fetchFailure(errorMessage))
        
        #expect(result.state.error == errorMessage)
        #expect(result.state.isLoading == false)
    }

    @Test("The fetch effect should return fetchSuccess when the service call succeeds")
    @MainActor
    func fetchEffectSuccess() async throws {
        let expectedName = "Mock Alice"
        Current.userService = MockUserService(result: .success(expectedName))
        
        let result = userFlow.run(UserState(), .fetchRequest)
        
        let effect = try #require(result.effects.first)
        let nextAction = await effect.operation()
        
        #expect(nextAction == .fetchSuccess(expectedName))
    }
}
