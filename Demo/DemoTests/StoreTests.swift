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
        var iterator = scopedStore.stateStream.dropFirst().makeAsyncIterator()
        
        rootStore.send(.counterAction(.increment))
        
        // Wait for AsyncStream propagation
        _ = await iterator.next()
        
        #expect(scopedStore.state.count == 1)
    }

    @MainActor
    @Test("Actions sent to a scoped store should update the state in the parent store")
    func scopedStoreSendsToParent() async throws {
        let rootStore = Store(initialState: AppState(), flow: rootFlow)
        var iterator = rootStore.stateStream.dropFirst().makeAsyncIterator()
        let scopedStore = rootStore.scope(state: \.counter, action: { .counterAction($0) })
        
        scopedStore.send(.increment)
        
        _ = await iterator.next()
        
        #expect(rootStore.state.counter.count == 1)
    }
}
