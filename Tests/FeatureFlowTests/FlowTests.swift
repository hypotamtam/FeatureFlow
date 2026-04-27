import Testing
@testable import FeatureFlow

@Suite("Flow Tests")
struct FlowTests {
    
    struct OptionalParentState: State {
        var child: TestState?
    }

    enum OptionalParentAction: Action {
        case childAction(TestAction)
        case removeChild
    }

    @Test("FlowBuilder executes multiple flows in sequence")
    func flowBuilder_BuildBlock() {
        let flowA = Flow<TestState, TestAction> { state, _ in
            .result(state.with { $0.count += 1 })
        }
        let flowB = Flow<TestState, TestAction> { state, _ in
            .result(state.with { $0.count *= 2 })
        }
        
        let combined = Flow<TestState, TestAction> {
            flowA
            flowB
        }
        
        let result = combined.run(TestState(count: 2), .increment(1))
        
        // (2 + 1) * 2 = 6
        #expect(result.state.count == 6)
    }

    @Test("FlowBuilder handles optional flows")
    func flowBuilder_BuildOptional() {
        func makeFlow(includeMultiplication: Bool) -> Flow<TestState, TestAction> {
            Flow {
                Flow { (state: TestState, _: TestAction) in .result(state.with { $0.count += 1 }) }
                
                if includeMultiplication {
                    Flow { (state: TestState, _: TestAction) in .result(state.with { $0.count *= 10 }) }
                }
            }
        }
        
        let trueResult = makeFlow(includeMultiplication: true).run(TestState(count: 2), .increment(1))
        #expect(trueResult.state.count == 30)
        
        let falseResult = makeFlow(includeMultiplication: false).run(TestState(count: 2), .increment(1))
        #expect(falseResult.state.count == 3)
    }

    @Test("FlowBuilder handles conditional branches (if/else)")
    func flowBuilder_BuildEither() {
        func makeFlow(isPremium: Bool) -> Flow<TestState, TestAction> {
            Flow {
                if isPremium {
                    Flow { (state: TestState, _: TestAction) in .result(state.with { $0.count += 100 }) }
                } else {
                    Flow { (state: TestState, _: TestAction) in .result(state.with { $0.count += 1 }) }
                }
            }
        }
        
        let premiumResult = makeFlow(isPremium: true).run(TestState(count: 0), .increment(1))
        #expect(premiumResult.state.count == 100)
        
        let standardResult = makeFlow(isPremium: false).run(TestState(count: 0), .increment(1))
        #expect(standardResult.state.count == 1)
    }

    @Test("Flow.pullback correctly maps child logic to parent domain")
    func flowPullback() {
        let result = combinedTestFlow.run(TestState(), .childAction(.increment))
        #expect(result.state.child.value == 1)
    }

    @Test("ifLet routes actions when state is present")
    func ifLetRoutesActions() {
        let parentFlow = Flow<OptionalParentState, OptionalParentAction> { state, action in
            switch action {
            case .removeChild:
                return .result(state.with { $0.child = nil })
            default:
                return .result(state)
            }
        }
        
        let childFlow = Flow<TestState, TestAction> { state, action in
            switch action {
            case .increment(let amount):
                return .result(state.with { $0.count += amount })
            default:
                return .result(state)
            }
        }
        
        let combinedFlow = Flow<OptionalParentState, OptionalParentAction> {
            parentFlow
            childFlow.ifLet(
                state: \.child,
                action: CasePath(
                    embed: OptionalParentAction.childAction,
                    extract: { action in
                        guard case let .childAction(child) = action else { return nil }
                        return child
                    }
                )
            )
        }
        
        // Test when child is present
        let stateWithChild = OptionalParentState(child: TestState(count: 0))
        let result1 = combinedFlow.run(stateWithChild, .childAction(.increment(5)))
        #expect(result1.state.child?.count == 5)
        
        // Test when child is nil (action is ignored)
        let stateWithoutChild = OptionalParentState(child: nil)
        let result2 = combinedFlow.run(stateWithoutChild, .childAction(.increment(5)))
        #expect(result2.state.child == nil)
        
        // Test removing child
        let result3 = combinedFlow.run(stateWithChild, .removeChild)
        #expect(result3.state.child == nil)
    }
}
