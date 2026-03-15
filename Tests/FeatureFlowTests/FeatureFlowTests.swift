// Tests/FeatureFlowTests/FeatureFlowTests.swift

import Testing
import Foundation
import Combine

@testable import FeatureFlow

// MARK: - Test Domain

struct SubState: State, Equatable {
    var value: Int = 0
}

enum SubAction: Action, Equatable {
    typealias State = SubState
    case increment
}

struct TestState: State, Equatable {
    var count: Int = 0
    var text: String = ""
    var child: SubState = .init()
}

enum TestAction: Action, Equatable {
    typealias State = TestState
    
    case increment(_ value: Int)
    case setText(String)
    case childAction(SubAction)
    case asyncIncrement(id: String, policy: EffectPolicy, value: Int)
}

// MARK: - Test Flows

let subFlow = Flow<SubAction> { state, action in
    switch action {
    case .increment:
        return .result(state.with { $0.value += 1 })
    }
}

let baseTestFlow = Flow<TestAction> { state, action in
    switch action {
    case .increment(let value):
        return .result(state.with { $0.count += value })
        
    case .setText(let text):
        return .result(state.with { $0.text = text })
        
    case .childAction:
        return .result(state)
        
    case let .asyncIncrement(id, policy, value):
        return .result(
            state,
            effect: Effect(id: id, policy: policy) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                return .increment(value)
            }
        )
    }
}

let combinedTestFlow = Flow<TestAction>.combine(
    baseTestFlow,
    subFlow.pullback(
        childPath: \.child,
        toChildAction: { 
            guard case let .childAction(action) = $0 else { return nil }
            return action
        },
        toParentAction: { .childAction($0) }
    )
)

// MARK: - Test Suite

@Suite("FeatureFlow Core Tests")
struct FeatureFlowTests {

    @Test("Flow.combine executes multiple flows in sequence")
    func flowCombine() {
        let flowA = Flow<TestAction> { state, _ in
            .result(state.with { $0.count += 1 })
        }
        let flowB = Flow<TestAction> { state, _ in
            .result(state.with { $0.count *= 2 })
        }
        
        let combined = Flow.combine(flowA, flowB)
        let result = combined.run(TestState(count: 2), .increment(1))
        
        // (2 + 1) * 2 = 6
        #expect(result.state.count == 6)
    }

    @Test("Flow.pullback correctly maps child logic to parent domain")
    func flowPullback() {
        let result = combinedTestFlow.run(TestState(), .childAction(.increment))
        #expect(result.state.child.value == 1)
    }

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
        
        #expect(childStore.state.value == 0)
        
        // Send to child store
        childStore.send(.increment)
        
        // Wait for @Published propagation via Combine
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(parentStore.state.child.value == 1)
        #expect(childStore.state.value == 1)
    }

    @MainActor
    @Test("Store.binding creates a working SwiftUI binding")
    func storeBinding() async {
        let store = ViewStore(initialState: TestState(), flow: baseTestFlow)
        var stateUpdateIterator = store.objectWillChange.values.makeAsyncIterator()
        
        let binding = store.binding(\.text, to: { .setText($0) })
        
        binding.wrappedValue = "New Value"
        
        await stateUpdateIterator.next()
        #expect(store.state.text == "New Value")
    }

    @Test("EffectPolicy.cancelPrevious cancels existing tasks with same ID")
    func effectCancellation() async throws {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        
        // Send two async increments with the same ID
        store.send(.asyncIncrement(id: "id", policy: .cancelPrevious, value: 1))
        // Wait slightly to ensure task is created
        try await Task.sleep(nanoseconds: 10_000_000)
        
        store.send(.asyncIncrement(id: "id", policy: .cancelPrevious, value: 2))
        
        // Wait for the duration of one effect (0.1s + buffer)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Only one increment should have succeeded (the first was cancelled)
        #expect(store.state.count == 2)
    }

    @Test("EffectPolicy.runIfMissing ignores new tasks if ID is active")
    func effectThrottling() async throws {
        let store = Store(initialState: TestState(), flow: baseTestFlow)
        
        // Send first async increment
        store.send(.asyncIncrement(id: "id", policy: .runIfMissing, value: 1))
        // Send second one immediately - should be ignored
        store.send(.asyncIncrement(id: "id", policy: .runIfMissing, value: 2))
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Only the first one should have counted
        #expect(store.state.count == 1)
    }
}
