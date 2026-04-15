import Testing
import Foundation
import Combine
@testable import FeatureFlow

// This file contains shared models and flows for all FeatureFlow tests.

// MARK: - Test Domain

struct SubState: State, Equatable {
    var value: Int = 0
}

enum SubAction: Action, Equatable {
    case increment
}

struct TestState: State, Equatable {
    var count: Int = 0
    var text: String = ""
    var child: SubState = .init()
}

enum TestAction: Action, Equatable {
    case increment(_ value: Int)
    case setText(String)
    case childAction(SubAction)
    case asyncIncrement(id: String, policy: EffectPolicy, value: Int)
}

// MARK: - Test Flows

let subFlow = Flow<SubState, SubAction> { state, action in
    switch action {
    case .increment:
        return .result(state.with { $0.value += 1 })
    }
}

let baseTestFlow = Flow<TestState, TestAction> { state, action in
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

let combinedTestFlow = Flow<TestState, TestAction> {
    baseTestFlow
    subFlow.pullback(
        childPath: \.child,
        toChildAction: {
            guard case let .childAction(action) = $0 else { return nil }
            return action
        },
        toParentAction: { .childAction($0) }
    )
}

