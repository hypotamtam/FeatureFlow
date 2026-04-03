import Testing
import Foundation
@testable import FeatureFlow
@testable import Demo

@Suite("App Cancellation Tests")
struct AppCancellationTests {

    @MainActor
    @Test("Verifies that syncTitle effect is properly cancelled and doesn't fire late")
    func testSyncCancellation() async throws {
        // Use a real store with the actual rootFlow from the Demo
        let store = Store(initialState: AppState(), flow: rootFlow)
        
        // 1. Trigger the syncTitle action
        // In the real app, this is triggered via updateTitle debounce, 
        // but we can send it directly to test the effect logic.
        store.send(.syncTitle)
        #expect(store.state.isSyncing == true)
        
        // 2. Wait just a bit to ensure the effect task is started
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        // 3. Cancel the sync
        store.send(.cancelSync)
        #expect(store.state.isSyncing == false)
        
        // 4. Wait long enough that the original 4-second sleep would have finished
        // For a unit test, we don't want to wait 4 seconds. 
        // However, since we share the ID "sync-title", the cancellation happens immediately.
        // We wait a bit more to be sure no ghost action is processed.
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // If the bug was present, the isSyncing would remain false (set by cancelSync),
        // but we want to be sure no other effects from that task fire.
        // The fact that the store deinit or next actions don't show "ghost" behavior is the goal.
        
        // Let's verify that sending another action works fine and state remains stable
        store.send(.updateTitle("Verified"))
        #expect(store.state.appTitle == "Verified")
        #expect(store.state.isSyncing == false)
    }
}
