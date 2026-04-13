# FeatureFlow

**FeatureFlow** is a lightweight, unidirectional data flow architecture for Swift, built from the ground up to leverage modern Swift Concurrency. It provides a structured way to manage state, logic, and side effects in a modular and testable fashion.

## Goal

The goal of FeatureFlow is to provide a predictable state management system similar to Redux or The Composable Architecture (TCA) but with a focus on simplicity and native Swift features like `async/await` and `Sendable` types. It aims to decouple business logic from the UI and make complex asynchronous side effects easy to manage.

## Requirements

- **Swift 6+** (utilizes strict concurrency features)
- **Platforms**: iOS 15.0+, macOS 13+, tvOS 15.0+, watchOS 8.0+

## Features

- **Unidirectional Data Flow**: State is read-only and can only be modified by sending actions through a "Flow".
- **Pure Logic**: `Flow` logic is isolated and predictable, making it easy to unit test.
- **Modern Effects**: Built-in support for asynchronous side effects using `async/await`.
- **Composition**: Use `pullback` and `combine` to build complex features out of smaller, independent modules.
- **Effect Management**: Native support for **Debounce**, **Throttle**, and **Cancellation** via `EffectPolicy`.
- **Type Safety** : Leverages Swift's type system to ensure actions and states are always compatible.

---

## Documentation

Explore the detailed guides to master FeatureFlow:

- [**Getting Started**](docs/GettingStarted.md): A step-by-step tutorial building your first feature.
- [**Side Effects**](docs/SideEffects.md): Deep dive into managing async work, debouncing, and throttling with `Effect`.
- [**Composition**](docs/Composition.md): Learn how to scale your app by nesting child features into parent domains.
- [**Exhaustive Testing**](docs/TestStore.md): How to use `TestStore` to verify logic and background effects.
- [**Comparison & Migration**](docs/Migration.md): How FeatureFlow compares to MVVM, TCA, and Redux.

---

## How to Use

### 1. Define State and Actions

Every feature starts with a `State` (what the user sees) and `Action` (what the user does).

```swift
struct CounterState: State {
    var count = 0
    var isProcessing = false
}

enum CounterAction: Action {
    case increment
    case delayedIncrement
}
```

### 2. Create a Flow

A Flow defines how the state changes in response to actions and what side effects (if any) should be triggered.

```swift
let counterFlow = Flow<CounterAction> { state, action in
    switch action {
    case .increment:
        return .result(state.with { $0.count += 1 })
        
    case .delayedIncrement:
        return .result(
            state.with { $0.isProcessing = true },
            effect: Effect {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return .increment
            }
        )
    }
}
```

### 3. Effect Management

FeatureFlow makes it easy to handle complex scenarios like debouncing search inputs or throttling button taps using Effect helpers.

```swift
case .updateSearch(let query):
    return .result(
        state.with { $0.query = query },
        effect: .debounce(id: "search-query", for: 0.3) {
            let results = await API.search(query)
            return .searchResponse(results)
        }
    )
```

### 4. Composition (Modularization)

You can scale your app by nesting child features into a parent "Root" flow using pullback and combine.

```swift
let rootFlow = Flow<AppAction>.combine(
    counterFlow.pullback(
        childPath: \.counter,
        toChildAction: { if case .counterAction(let a) = $0 { return a }; return nil },
        toParentAction: { .counterAction($0) }
    ),
    appFlow
)
```

### 5. SwiftUI Integration

Connect your Flow to a SwiftUI view using `ObservableViewStore` (for iOS 17+ via `@Observable`) or `ViewStore` (for iOS 15+ via `@ObservedObject`).

```swift
import SwiftUI
import FeatureFlow

// 1. Wrap the Store in the ViewStore
struct CounterView: View {
    @State var viewStore: ObservableViewStore<CounterState, CounterAction>

    var body: some View {
        VStack {
            // 2. Read state automatically
            Text("Count: \(viewStore.state.count)")
            
            // 3. Dispatch actions
            Button("Increment") {
                viewStore.send(.increment)
            }

            // 4. Two-way bindings for UI controls
            Toggle(
                "Processing",
                isOn: viewStore.binding(\.isProcessing, to: { .setProcessing($0) })
            )
        }
    }
}
```

## Testing

FeatureFlow provides a dedicated `TestStore` that makes it easy to rigorously assert step-by-step state mutations and intercept asynchronous background effects. The `TestStore` guarantees determinism and ensures no effect is left unhandled.

Read the [Exhaustive Testing with TestStore](docs/TestStore.md) guide for examples on how to test races, cancellation, and external streams.

## Demo Application

A fully functional demo app is included to showcase these concepts in practice. It demonstrates everything from simple state mutations to complex async effect handling and composition.

- Open `Demo/Demo.xcodeproj` or the Swift Package in Xcode.
- Select the `Demo` scheme and run it on a simulator or device.

## Installation

### Swift Package Manager

Add FeatureFlow to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/thomascassany/FeatureFlow.git", from: "1.0.0")
]
```
Or in Xcode:

1. Go to **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/thomascassany/FeatureFlow.git`
3. Select your desired version rules and add the package to your target.


