import Testing
import Foundation
import FeatureFlow
import FeatureFlowTesting

@Suite("TestStore Tests")
struct TestStoreTests {

    struct TestState: State, Equatable {
        var count = 0
        var text = ""
    }

    enum TestAction: Action, Equatable {
        case increment
        case setText(String)
        case triggerEffect
        case triggerSilentEffect
        case effectResult(Int)
        case cancelEffect
    }

    @MainActor
    @Test("TestStore asserts simple state mutations")
    func simpleMutation() async {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .increment:
                return .result(state.with { $0.count += 1 })
            case .setText(let text):
                return .result(state.with { $0.text = text })
            default:
                return .result(state)
            }
        }
        
        let store = TestStore(initialState: TestState(), flow: flow)
        
        await store.send(.increment) {
            $0.count = 1
        }
        
        await store.send(.setText("Hello")) {
            $0.text = "Hello"
        }
    }

    @MainActor
    @Test("TestStore correctly receives actions from effects")
    func asyncEffects() async {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .triggerEffect:
                return .result(state, effect: Effect {
                    return .effectResult(42)
                })
            case .effectResult(let value):
                return .result(state.with { $0.count = value })
            default:
                return .result(state)
            }
        }
        
        let store = TestStore(initialState: TestState(), flow: flow)
        
        await store.send(.triggerEffect)
        
        await store.receive(.effectResult(42)) {
            $0.count = 42
        }
    }

    @MainActor
    @Test("TestStore handles receiveNoAction for silent effects")
    func silentEffects() async {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .triggerSilentEffect:
                return .result(state, effect: Effect {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                    return nil
                })
            default:
                return .result(state)
            }
        }
        
        let store = TestStore(initialState: TestState(), flow: flow)
        
        await store.send(.triggerSilentEffect)
        
        // This should wait for the task to finish
        await store.receiveNoAction()
    }

    @MainActor
    @Test("TestStore respects cancellation policies")
    func effectCancellation() async {
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .triggerEffect:
                return .result(state, effect: Effect(id: "id") {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    return .effectResult(1)
                })
            case .cancelEffect:
                return .result(state, effect: .cancel(id: "id"))
            default:
                return .result(state)
            }
        }
        
        let store = TestStore(initialState: TestState(), flow: flow)
        
        await store.send(.triggerEffect)
        
        // Cancel immediately
        await store.send(.cancelEffect)
        
        // Assert that the cancellation finished without emitting the result
        await store.receiveNoAction()
    }

    @MainActor
    @Test("TestStore handles receive with triggering closure")
    func receiveWithTriggering() async {
        // We use a continuation to simulate a long-living stream or external event
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        
        let flow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .triggerEffect:
                return .result(state, effect: Effect {
                    var iterator = stream.makeAsyncIterator()
                    let value = await iterator.next() ?? 0
                    return .effectResult(value)
                })
            case .effectResult(let value):
                return .result(state.with { $0.count = value })
            default:
                return .result(state)
            }
        }
        
        let store = TestStore(initialState: TestState(), flow: flow)
        
        await store.send(.triggerEffect)
        
        // Use the new overload to trigger the value and receive the result in one go
        await store.receive(.effectResult(100), triggering: {
            continuation.yield(100)
        }) {
            $0.count = 100
        }
    }
}
