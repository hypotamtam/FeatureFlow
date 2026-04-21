import Testing
import FeatureFlow
import FeatureFlowTesting
import Foundation

@CasePathable
enum RootAction: Sendable, Equatable {
    case child(ChildAction)
    case other
}

enum ChildAction: Sendable, Equatable {
    case increment
}

struct RootState: State {
    var child = ChildState()
}

struct ChildState: State {
    var count = 0
}

@Suite("CasePath and Macro Integration")
struct CasePathTests {
    
    @Test("CasePath embed and extract work correctly")
    func casePathBehavior() {
        let path = RootAction.Cases.child
        
        // Test embed
        let action = path.embed(.increment)
        #expect(action == .child(.increment))
        
        // Test extract success
        let extracted = path.extract(.child(.increment))
        #expect(extracted == .increment)
        
        // Test extract failure
        let failedExtraction = path.extract(.other)
        #expect(failedExtraction == nil)
    }
    
    @Test("Flow.pullback works with CasePath")
    func pullbackWithCasePath() {
        let childFlow = Flow<ChildState, ChildAction> { state, action in
            switch action {
            case .increment:
                return .result(state.with { $0.count += 1 })
            }
        }
        
        let rootFlow: Flow<RootState, RootAction> = childFlow.pullback(
            state: \RootState.child,
            action: RootAction.Cases.child
        )
        
        let result = rootFlow.run(RootState(), .child(.increment))
        #expect(result.state.child.count == 1)
    }
    
    @Test("Store.scope works with CasePath")
    func storeScopeWithCasePath() async {
        let childFlow = Flow<ChildState, ChildAction> { state, action in
            switch action {
            case .increment:
                return .result(state.with { $0.count += 1 })
            }
        }
        
        let rootFlow = Flow<RootState, RootAction> {
            childFlow.pullback(
                state: \RootState.child,
                action: RootAction.Cases.child
            )
        }
        
        let store = Store(initialState: RootState(), flow: rootFlow)
        let childStore: Store<ChildState, ChildAction> = store.scope(
            state: \RootState.child,
            action: RootAction.Cases.child
        )
        var iterator = childStore.stateStream.dropFirst().makeAsyncIterator()
        
        childStore.send(.increment)
        
        // Wait for state propagation
        _ = await iterator.next()
        
        #expect(store.state.child.count == 1)
        #expect(childStore.state.count == 1)
    }
}
