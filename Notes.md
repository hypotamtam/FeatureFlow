# Future Evaluations & Improvements

## Architecture

- [ ] **Evaluate `SwiftAsyncAlgorithms`**: Investigate using `AsyncBroadcaster` or other primitives from the [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) library to replace the current manual `AsyncStream` continuation management in `Store.swift`. This could provide a more standardized "multicast" behavior for state updates.

## Testing Architecture

- [ ] **TestStore Isolation (`@MainActor class` vs `actor`)**: 
  Evaluated converting `TestStore` from a `@MainActor class` to a pure `actor` to allow test suites to run concurrently off the main thread. Decided to **keep it as a `@MainActor class`** for the following reasons:
  * **Ergonomics**: As an `actor`, every state read and assertion in a test would require an `await` (e.g., `let count = await store.state.count`), making tests significantly more verbose.
  * **Production Parity**: The real `Store` driving the application must be `@MainActor` to bind seamlessly to SwiftUI components. Keeping `TestStore` on the `@MainActor` closely mirrors this production environment.
  * **Task Inheritance & Weak Self**: Because it relies on the global `@MainActor`, internal asynchronous tasks (like `Task { [weak self] in ... }` in `processEffects`) safely inherit isolation, allowing mutations to properties like `receivedActions` without data races. If `TestStore` were an instance `actor`, a `[weak self]` capture would strip the isolation, requiring more complex `await` hopping.
  * *Future Consideration*: If the test suite grows massive and execution speed becomes a severe bottleneck, this could be reconsidered, accepting the tradeoff of more verbose `await`-heavy tests for the benefit of parallel background execution.
