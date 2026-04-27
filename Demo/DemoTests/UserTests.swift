import Testing
import Foundation
import FeatureFlow
import FeatureFlowTesting
@testable import Demo

struct MockUserService: UserServiceProtocol {
    var result: Result<String, Error>
    
    func fetchUser() async throws -> String {
        try result.get()
    }
}

@Suite("User Domain Tests", .serialized)
struct UserTests {
    
    @Test("The initial state should have the correct default values")
    func initialState() {
        let state = UserState()
        #expect(state.name == "Unknown User")
        #expect(state.isLoading == false)
        #expect(state.error == nil)
    }

    @MainActor
    @Test("Initiating a user fetch request should set isLoading to true")
    func fetchRequest() async {
        let expectedName = "Alice"
        Current.userService = MockUserService(result: .success(expectedName))
        
        let store = TestStore(initialState: UserState(error: "Previous connection error"), flow: userFlow)
        
        await store.send(.fetchRequest) {
            $0.isLoading = true
            $0.error = nil
        }
        
        // Assert the background effect completes
        await store.receive(.fetchSuccess(expectedName)) {
            $0.isLoading = false
            $0.name = expectedName
        }
    }

    @MainActor
    @Test("A successful user fetch should update the name")
    func fetchSuccess() async {
        let store = TestStore(initialState: UserState(isLoading: true), flow: userFlow)
        
        await store.send(.fetchSuccess("Jane Doe")) {
            $0.name = "Jane Doe"
            $0.isLoading = false
        }
    }

    @MainActor
    @Test("A failed user fetch should capture the error message")
    func fetchFailure() async {
        let store = TestStore(initialState: UserState(isLoading: true), flow: userFlow)
        
        let errorMessage = "Access Denied"
        await store.send(.fetchFailure(errorMessage)) {
            $0.error = errorMessage
            $0.isLoading = false
        }
    }

    @MainActor
    @Test("The fetch effect should return fetchSuccess when the service call succeeds")
    func fetchEffectSuccess() async throws {
        let expectedName = "Mock Alice"
        Current.userService = MockUserService(result: .success(expectedName))
        
        let store = TestStore(initialState: UserState(), flow: userFlow)
        
        await store.send(.fetchRequest) {
            $0.isLoading = true
        }
        
        await store.receive(.fetchSuccess(expectedName)) {
            $0.isLoading = false
            $0.name = expectedName
        }
    }

    // MARK: - Profile Editor TDD Tests

    @MainActor
    @Test("Opening the editor should initialize the edit state")
    func openEditor() async {
        let store = TestStore(initialState: UserState(name: "Alice"), flow: userFlow)

        await store.send(.showEditor) {
            $0.editProfile = EditProfileState(draftName: "Alice")
        }
    }

    @MainActor
    @Test("Dismissing the editor should clear the edit state")
    func dismissEditor() async {
        let store = TestStore(
            initialState: UserState(
                name: "Alice",
                editProfile: EditProfileState(draftName: "Alice")
            ),
            flow: userFlow
        )

        await store.send(.dismissEditor) {
            $0.editProfile = nil
        }
        
        // Wait for the .cancel effect to finish
        await store.receiveNoAction()
    }

    @MainActor
    @Test("Editing the draft name should only update the draft")
    func updateDraftName() async {
        let store = TestStore(
            initialState: UserState(
                name: "Alice",
                editProfile: EditProfileState(draftName: "Alice")
            ),
            flow: userFlow
        )

        await store.send(.editProfile(.updateName("Bob"))) {
            $0.editProfile?.draftName = "Bob"
        }
        
        #expect(store.state.name == "Alice")
    }

    @MainActor
    @Test("A successful save should update the user name and dismiss the editor")
    func saveSuccess() async {
        let store = TestStore(
            initialState: UserState(
                name: "Alice",
                editProfile: EditProfileState(draftName: "Bob")
            ),
            flow: userFlow
        )

        await store.send(.editProfile(.saveTapped)) {
            $0.editProfile?.isSaving = true
        }

        // Increase timeout to 2 seconds to accommodate the 1-second sleep
        await store.receive(.editProfile(.saveSuccess("Bob")), timeout: 2.0) {
            $0.name = "Bob"
            $0.editProfile = nil
        }
    }

    @MainActor
    @Test("A failed save should stop the loading state but keep the editor open")
    func saveFailure() async {
        let store = TestStore(
            initialState: UserState(
                name: "Alice",
                editProfile: EditProfileState(draftName: "Bob", isSaving: true)
            ),
            flow: userFlow
        )

        await store.send(.editProfile(.saveFailure("Network Error"))) {
            $0.editProfile?.isSaving = false
            // Note: We might want to add an error message to EditProfileState later
        }
        
        #expect(store.state.editProfile != nil)
        #expect(store.state.name == "Alice")
    }
}
