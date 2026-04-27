import Testing
import Foundation
import FeatureFlow
import FeatureFlowTesting
@testable import Demo

struct EditProfileTests {
    @MainActor
    @Test("Updating the name changes the draft name")
    func updateName() async {
        let store = TestStore(
            initialState: EditProfileState(draftName: "Alice"),
            flow: editProfileFlow
        )

        await store.send(.updateName("Bob")) {
            $0.draftName = "Bob"
        }
    }

    @MainActor
    @Test("Saving triggers an effect that succeeds")
    func saveSuccess() async {
        let store = TestStore(
            initialState: EditProfileState(draftName: "Bob"),
            flow: editProfileFlow
        )

        await store.send(.saveTapped) {
            $0.isSaving = true
        }

        // Wait for the simulated 1-second delay
        await store.receive(.saveSuccess("Bob"), timeout: 3.0) {
            $0.isSaving = false
        }
    }

    @MainActor
    @Test("A failed save resets the saving state")
    func saveFailure() async {
        let store = TestStore(
            initialState: EditProfileState(draftName: "Bob", isSaving: true),
            flow: editProfileFlow
        )

        await store.send(.saveFailure("Error")) {
            $0.isSaving = false
        }
    }
}
