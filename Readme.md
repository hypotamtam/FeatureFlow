# FeatureFlow

**FeatureFlow** is a lightweight, unidirectional data flow architecture for Swift, built from the ground up to leverage modern Swift Concurrency. It provides a structured way to manage state, logic, and side effects in a modular and testable fashion.

## Goal

The goal of FeatureFlow is to provide a predictable state management system—similar to Redux or The Composable Architecture (TCA)—but with a focus on simplicity and native Swift features like `async/await` and `Sendable` types. It aims to decouple business logic from the UI and make complex asynchronous side effects easy to manage.

## Requirements

- **Swift 6+** (utilizes strict concurrency features)
- **Platforms**: iOS 16.0+, macOS 13+, tvOS 16.0+, watchOS 9.0+

## Features

- **Unidirectional Data Flow**: State is read-only and can only be modified by sending actions through a "Flow".
- **Pure Logic**: `Flow` logic is isolated and predictable, making it easy to unit test.
- **Modern Effects**: Built-in support for asynchronous side effects using `async/await`.
- **Composition**: Use `pullback` and `combine` to build complex features out of smaller, independent modules.
- **Effect Management**: Native support for **Debounce**, **Throttle**, and **Cancellation** via `EffectPolicy`.
- **Type Safety**: Leverages Swift's type system to ensure actions and states are always compatible.

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
    typealias State = CounterState
    
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


