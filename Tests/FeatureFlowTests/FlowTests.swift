// Tests/FeatureFlowTests/FlowTests.swift

import Testing
@testable import FeatureFlow

@Suite("Flow Tests")
struct FlowTests {

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
}
