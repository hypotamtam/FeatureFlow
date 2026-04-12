# Getting Started with FeatureFlow

Welcome to FeatureFlow! This guide will walk you through building your first feature: a simple, persistent counter. You'll learn how to define your domain, write pure business logic, handle side effects, and connect it all to a SwiftUI view.

## 1. Define the Domain (State & Action)

Every feature starts with two types:

*   **State:** A struct holding the data required to render the feature. It must conform to `FeatureFlow.State`.
*   **Action:** An enum defining all the events that can happen in the feature (user interactions, network responses, etc.). It must conform to `FeatureFlow.Action`.

Let's create a `CounterState` and a `CounterAction`:

```swift
import FeatureFlow

struct CounterState: State {
    var count = 0
    var isLoading = false
}

enum CounterAction: Action {
    typealias State = CounterState
    
    case increment
    case decrement
    case fetchRandomFact
    case randomFactResponse(String)
}
```

## 2. Write the Logic (Flow)

The `Flow` is where your business logic lives. It is a pure function that takes the current `State` and an `Action`, and returns a `Result`. The `Result` contains the mutated state and an optional asynchronous `Effect`.

```swift
import Foundation
import FeatureFlow

let counterFlow = Flow<CounterAction> { state, action in
    switch action {
    case . increment:
        return .result(state.with { $0.count += 1 })
        
    case . decrement:
        return .result(state.with { $0.count -= 1 })
        
    case .fetchRandomFact:
        // Set loading state and trigger a side effect
        return .result(
            state.with { $0.isLoading = true },
            effect: Effect {
                // Simulate an API call
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let mockFact = "The number \(state.count) is awesome!"
                return .randomFactResponse(mockFact)
            }
        )
        
    case .randomFactResponse(let fact):
        // Handle the effect's result
        print("Fact received: \(fact)")
        return .result(state.with { $0.isLoading = false })
    }
}
```

*Note: We use `state.with { ... }` to make a mutable copy of the state, mutate it, and return it. State is never mutated in-place outside of this closure.*

## 3. Connect to SwiftUI

To drive your UI, create a `Store` with your initial state and flow, and wrap it in an `ObservableViewStore` (if targeting iOS 17+) or `ViewStore` (for iOS 16+).

```swift
import SwiftUI
import FeatureFlow

struct CounterView: View {
    // 1. Hold the view store
    @State var viewStore: ObservableViewStore<CounterState, CounterAction>
    
    var body: some View {
        VStack(spacing: 20) {
            // 2. Read state directly
            Text("Count: \(viewStore.state.count)")
                .font(.largeTitle)
            
            HStack {
                // 3. Send actions
                Button("-") { viewStore.send(.decrement) }
                Button("+") { viewStore.send(.increment) }
            }
            .font(.title)
            
            Button("Get Random Fact") {
                viewStore.send(.fetchRandomFact)
            }
            .disabled(viewStore.state.isLoading)
            
            if viewStore.state.isLoading {
                ProgressView()
            }
        }
        .padding()
    }
}

// 4. Preview it
#Preview {
    CounterView(
        viewStore: ObservableViewStore(
            initialState: CounterState(),
            flow: counterFlow
        )
    )
}
```

## Next Steps

Congratulations! You've built your first feature using a strict, unidirectional data flow. 

*   Learn how to manage complex async operations in the [Side Effects Guide](SideEffects.md).
*   Learn how to scale your app by combining multiple flows in the [Composition Guide](Composition.md).
*   Learn how to test your logic rigorously in the [Testing Guide](TestStore.md).
