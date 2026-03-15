// Tests/FeatureFlowTests/ViewStoreTests.swift

import Testing
import Combine
@testable import FeatureFlow

@Suite("ViewStore Tests")
struct ViewStoreTests {

    @MainActor
    @Test("Store.binding creates a working SwiftUI binding")
    func storeBinding() async throws {
        let viewStore = ViewStore(initialState: TestState(), flow: baseTestFlow)
        
        let binding = viewStore.binding(\.text, to: { .setText($0) })
        
        binding.wrappedValue = "New Value"
        
        var isDone = false
        var sleepTime = 0
        while isDone == false {
            try await Task.sleep(nanoseconds: 10_000)
            sleepTime += 10_000
            isDone = (viewStore.state.text == "New Value") || (sleepTime == 100_000)
        }
        #expect(viewStore.state.text == "New Value")
    }
}
