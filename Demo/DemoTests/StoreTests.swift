import Testing
import FeatureFlow
import FeatureFlowTesting
@testable import Demo

@Suite("Store Scoping Tests")
struct StoreTests {
    @MainActor
    @Test("A scoped store should reflect state changes made in its parent store")
    func scopedStoreReceivesParentUpdates() async throws {
        let rootStore = Store(initialState: AppState(), flow: rootFlow)
        let scopedStore = rootStore.scope(state: \.counter, action: { .counterAction($0) })
        
        rootStore.send(.counterAction(.increment))
        
        // Wait for AsyncStream propagation
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(scopedStore.state.count == 1)
    }

    @MainActor
    @Test("Actions sent to a scoped store should update the state in the parent store")
    func scopedStoreSendsToParent() async throws {
        let rootStore = Store(initialState: AppState(), flow: rootFlow)
        let scopedStore = rootStore.scope(state: \.counter, action: { .counterAction($0) })
        
        scopedStore.send(.increment)
        
        // Wait for AsyncStream propagation
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(rootStore.state.counter.count == 1)
    }
}
