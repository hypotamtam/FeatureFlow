import Testing
import Foundation
@testable import FeatureFlow

@Suite("Store Tests")
struct StoreTests {

    @Test("Store updates state and notifies observers")
    func storeStateUpdates() async {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        
        store.send(.increment(1))
        #expect(store.state.count == 1)
        
        store.send(.setText("Hello"))
        #expect(store.state.text == "Hello")
    }

    @Test("Store.scope creates a child store that synchronizes with the parent")
    func storeScoping() async throws {
        let parentStore = Store(initialState: TestState(), flow: combinedTestFlow)
        let childStore = parentStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        // Waiting for childStore.stateStream makes sure both stores are updated as
        // the child state is updated after the parent one.
        let iterator = childStore.stateStream.dropFirst()
        
        #expect(childStore.state.value == 0)
        
        childStore.send(.increment)
        
        _ = await iterator.next()
        
        #expect(parentStore.state.child.value == 1)
        #expect(childStore.state.value == 1)
    }

    @Test("Store handles concurrent sends correctly")
    func storeConcurrentSends() async {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        let count = 1000
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask {
                    store.send(.increment(1))
                }
            }
        }
        
        #expect(store.state.count == count)
    }

    @Test("Scoped store receives parent updates correctly")
    func scopedStoreReceivesParentUpdates() async throws {
        let parentStore = Store(initialState: TestState(), flow: combinedTestFlow)
        let childStore = parentStore.scope(
            state: \.child,
            action: { .childAction($0) }
        )
        // Waiting for childStore.stateStream makes sure both stores are updated as
        // the child state is updated after the parent one.
        let iterator = childStore.stateStream.dropFirst()
        
        #expect(childStore.state.value == 0)
        
        parentStore.send(.childAction(.increment))
        
        // Wait for the AsyncStream to propagate the change down to the child store
        _ = await iterator.next()
        
        #expect(parentStore.state.child.value == 1)
        #expect(childStore.state.value == 1)
    }

    @Test("All tasks are cancelled on Store deinit")
    func storeDeinitCancelsAllTasks() async throws {
        let (identifiedStream, identifiedContinuation) = AsyncStream.makeStream(of: Void.self)
        let (anonymousStream, anonymousContinuation) = AsyncStream.makeStream(of: Void.self)
        
        var store: Store<TestState, TestAction>? = Store(
            initialState: TestState(),
            flow: Flow { state, action in
                switch action {
                case .increment:
                    return .result(
                        state,
                        effects: [
                            Effect(id: "identified") {
                                do {
                                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                                    return nil
                                } catch {
                                    identifiedContinuation.yield(())
                                    return nil as TestAction?
                                }
                            },
                            Effect {
                                do {
                                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                                    return nil
                                } catch {
                                    anonymousContinuation.yield(())
                                    return nil as TestAction?
                                }
                            }
                        ]
                    )
                default:
                    return .result(state)
                }
            }
        )
        
        store?.send(.increment(1))
        
        // Brief sleep to ensure tasks have started
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Deinit the store
        store = nil
        
        // Verify cancellation signals were received with a timeout
        let identifiedCancelled = await identifiedStream.next() != nil
        let anonymousCancelled = await anonymousStream.next() != nil
        
        #expect(identifiedCancelled, "Identified task should have been cancelled")
        #expect(anonymousCancelled, "Anonymous task should have been cancelled")
    }
}
