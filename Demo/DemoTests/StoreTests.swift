import Testing
@testable import FeatureFlow
@testable import Demo

@Suite("Store Scoping Tests")
struct StoreTests {
    @MainActor
    @Test("A scoped store should reflect state changes made in its parent store")
    func scopedStoreReceivesParentUpdates() {
        let rootStore = Store(initialState: AppState(), flow: rootFlow)
        let scopedStore = rootStore.scope(state: \.counter, action: { .counterAction($0) })
        
        rootStore.send(.counterAction(.increment))
        
        #expect(scopedStore.state.count == 1)
    }

    @MainActor
    @Test("Actions sent to a scoped store should update the state in the parent store")
    func scopedStoreSendsToParent() {
        let rootStore = Store(initialState: AppState(), flow: rootFlow)
        let scopedStore = rootStore.scope(state: \.counter, action: { .counterAction($0) })
        
        scopedStore.send(.increment)
        
        #expect(rootStore.state.counter.count == 1)
    }
}
