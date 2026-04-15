import Testing
import FeatureFlowTesting
@testable import FeatureFlow
@testable import Demo

@Suite("App Domain Tests", .serialized)
struct AppTests {
    
    @Test("isGlobalLoading is true if any subdomain is loading")
    func globalLoadingAggregration() {
        var state = AppState()
        
        state.user.isLoading = true
        #expect(state.isGlobalLoading == true)
        
        state.user.isLoading = false
        state.counter.isProcessing = true
        #expect(state.isGlobalLoading == true)
        
        state.counter.isProcessing = false
        #expect(state.isGlobalLoading == false)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test("The app flow updates the title correctly")
    func updateTitle() async {
        let flow = createRootFlow(clock: ImmediateClock())
        let store = TestStore(initialState: AppState(), flow: flow)
        
        await store.send(.updateTitle("New Title")) {
            $0.appTitle = "New Title"
        }
        
        // .updateTitle triggers a debounced effect (1s).
        // Since we use ImmediateClock, it fires instantly.
        await store.receive(.syncTitle) {
            $0.isSyncing = true
        }
        
        // .syncTitle triggers a 4s sleep and then .cancelSync.
        // Again, ImmediateClock makes it instant.
        await store.receive(.cancelSync) {
            $0.isSyncing = false
        }
        
        // .cancelSync triggers a cancel(id: "sync-title") which is a silent effect.
        await store.receiveNoAction()
    }

    @MainActor
    @Test("The legacy app flow updates the title correctly")
    func updateTitleLegacy() async throws {
        let store = Store(initialState: AppState(), flow: rootFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.updateTitle("New Title"))
        
        let immediateState = await iterator.next()
        #expect(immediateState?.appTitle == "New Title")
        #expect(immediateState?.isSyncing == false)
        
        let syncTitleState = await iterator.next()
        #expect(syncTitleState?.isSyncing == true)
        
        let cancelSyncState = await iterator.next()
        #expect(cancelSyncState?.isSyncing == false)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test("The app flow correctly pullbacks counter actions")
    func pullbackCounterAction() async {
        let store = TestStore(initialState: AppState(), flow: createRootFlow(clock: ImmediateClock()))
        
        await store.send(.counterAction(.increment)) {
            $0.counter.count = 1
        }
    }

    @MainActor
    @Test("The legacy app flow correctly pullbacks counter actions")
    func pullbackCounterActionLegacy() async throws {
        // Legacy flow doesn't use dependency injection for clocks, so we use the raw Store.
        let store = Store(initialState: AppState(), flow: rootFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.counterAction(.increment))
        
        let state = await iterator.next()
        #expect(state?.counter.count == 1)
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test("The app flow correctly pullbacks user actions")
    func pullbackUserAction() async {
        let store = TestStore(initialState: AppState(), flow: createRootFlow(clock: ImmediateClock()))
        
        await store.send(.userAction(.fetchSuccess("Alice"))) {
            $0.user.name = "Alice"
        }
    }

    @MainActor
    @Test("The legacy app flow correctly pullbacks user actions")
    func pullbackUserActionLegacy() async throws {
        // Legacy flow doesn't use dependency injection for clocks, so we use the raw Store.
        let store = Store(initialState: AppState(), flow: rootFlowLegacy)
        var iterator = store.stateStream.dropFirst().makeAsyncIterator()
        
        store.send(.userAction(.fetchSuccess("Alice")))
        
        let state = await iterator.next()
        #expect(state?.user.name == "Alice")
    }

}
