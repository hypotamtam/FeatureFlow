import Testing
import FeatureFlowTesting
@testable import FeatureFlow
@testable import Demo

@Suite("App Domain Tests")
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

    @MainActor
    @Test("The app flow updates the title correctly")
    func updateTitle() {
        let result = rootFlow.run(AppState(), .updateTitle("New Title"))
        #expect(result.state.appTitle == "New Title")
    }

    @MainActor
    @Test("The app flow correctly pullbacks counter actions")
    func pullbackCounterAction() {
        let initialState = AppState()
        let result = rootFlow.run(initialState, .counterAction(.increment))
        
        #expect(result.state.counter.count == 1)
    }

    @MainActor
    @Test("The app flow correctly pullbacks user actions")
    func pullbackUserAction() {
        let initialState = AppState()
        let result = rootFlow.run(initialState, .userAction(.fetchSuccess("Alice")))
        
        #expect(result.state.user.name == "Alice")
    }
    
    @MainActor
    @Test("The app flow correctly stops the title sync with cancelSync")
    func cancelSyncCleanning() async throws {
        let flow = createRootFlow(clock: ImmediateClock())
        let store = TestStore(initialState: AppState(), flow: flow)
        
        await store.send(.updateTitle("hello")) {
            $0.appTitle = "hello"
        }
        
        await store.send(.syncTitle) {
            $0.isSyncing = true
        }
        
        await store.send(.cancelSync) {
            $0.isSyncing = false
        }
        
        // Assert that the cancellation effect (which returns nil) finishes.
        await store.receiveNoAction()
    }
}
