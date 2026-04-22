# Future Evaluations & Improvements

## Architecture

- [ ] **Evaluate `SwiftAsyncAlgorithms`**: Investigate using `AsyncBroadcaster` or other primitives from the [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) library to replace the current manual `AsyncStream` continuation management in `Store.swift`. This could provide a more standardized "multicast" behavior for state updates.

## Core Features & Operators

- [ ] **Implement `ifLet` Operator**: Add a higher-order flow operator to handle optional child features.
  * **Goal**: Simplify the composition of features that only exist "sometimes" (e.g., modals, sheets).
  * **Key Benefit**: Automatically handles "presence" checks and, crucially, provides **automatic effect cancellation** when the child state becomes `nil`, ensuring no background tasks leak after a feature is dismissed.

- [ ] **Implement `Flow.forEach` Operator**: Add support for dynamic collections of features.
  * **Goal**: Transform a single-item `Flow` into a collection-aware `Flow` that operates on an `IdentifiedArray` or similar collection.
  * **Key Benefit**: Removes the boilerplate of manual index management and ID-based action routing. Like `ifLet`, it should handle the lifecycle of child effects, ensuring that removing an item from the list cancels its specific background tasks.

- [ ] **Implement `Flow.log()` Higher-Order Flow**: Provide built-in diagnostics for state changes and actions.
  * **Goal**: Add a `.log()` or `.debug()` operator that can be attached to any flow to print a formatted trace to the console.
  * **Key Benefit**: Dramatically improves the developer experience by allowing real-time inspection of state mutations and side-effect triggers without adding manual print statements.

## Testing Architecture

- [ ] **TestStore Isolation (`@MainActor class` vs `actor`)**: 
  Evaluated converting `TestStore` from a `@MainActor class` to a pure `actor` to allow test suites to run concurrently off the main thread. Decided to **keep it as a `@MainActor class`** for the following reasons:
  * **Ergonomics**: As an `actor`, every state read and assertion in a test would require an `await` (e.g., `let count = await store.state.count`), making tests significantly more verbose.
  * **Production Parity**: The real `Store` driving the application must be `@MainActor` to bind seamlessly to SwiftUI components. Keeping `TestStore` on the `@MainActor` closely mirrors this production environment.
  * **Task Inheritance & Weak Self**: Because it relies on the global `@MainActor`, internal asynchronous tasks (like `Task { [weak self] in ... }` in `processEffects`) safely inherit isolation, allowing mutations to properties like `receivedActions` without data races. If `TestStore` were an instance `actor`, a `[weak self]` capture would strip the isolation, requiring more complex `await` hopping.
  * *Future Consideration*: If the test suite grows massive and execution speed becomes a severe bottleneck, this could be reconsidered, accepting the tradeoff of more verbose `await`-heavy tests for the benefit of parallel background execution.
