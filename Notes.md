# Future Evaluations & Improvements

## Architecture

- [ ] **Evaluate `SwiftAsyncAlgorithms`**: Investigate using `AsyncBroadcaster` or other primitives from the [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) library to replace the current manual `AsyncStream` continuation management in `Store.swift`. This could provide a more standardized "multicast" behavior for state updates.

## Core Features & Operators

- [ ] **Implement `Flow.forEach` Operator**: Add support for dynamic collections of features.
  * **Goal**: Transform a single-item `Flow` into a collection-aware `Flow` that operates on an `IdentifiedArray` or similar collection.
  * **Key Benefit**: Removes the boilerplate of manual index management and ID-based action routing. Like `ifLet`, it should handle the lifecycle of child effects, ensuring that removing an item from the list cancels its specific background tasks.

- [ ] **Implement `Flow.log()` Higher-Order Flow**: Provide built-in diagnostics for state changes and actions.
  * **Goal**: Add a `.log()` or `.debug()` operator that can be attached to any flow to print a formatted trace to the console.
  * **Key Benefit**: Dramatically improves the developer experience by allowing real-time inspection of state mutations and side-effect triggers without adding manual print statements.

## UI / Presentation

- [ ] **State-Driven Navigation Modifiers (vs `IfLetStore`)**:
  Currently, to present optional state (like sheets or popovers), we rely on wrapping the content inside an `IfLetStore` within a native SwiftUI presentation modifier.
  
  ```swift
  .sheet(isPresented: ...) {
      IfLetStore(store: store, state: \.child, action: ParentAction.child) { childStore in
          ChildView(store: childStore)
      }
  }
  ```
  
  **Proposed Improvement:** Create custom SwiftUI View Modifiers that accept the `store`, `state` keypath, and `action` case path directly. This hides the `IfLetStore` caching logic completely and provides a much cleaner, more native-feeling call site.
  
  ```swift
  .sheet(
      store: store, 
      state: \.child, 
      action: ParentAction.child
  ) { childStore in
      ChildView(store: childStore)
  }
  ```
  
  *Considerations for implementation:*
  *   We would need to build a suite of modifiers (`.sheet`, `.popover`, `.fullScreenCover`, `.navigationDestination`) to maintain parity with SwiftUI.
  *   The modifiers must gracefully handle interactive dismissal by the user (e.g., swiping down), meaning the framework must know exactly what action to dispatch to `nil` out the state. This might require the signature to also include an explicit `onDismiss: Action` parameter, slightly complicating the API.

## Testing Architecture

- [ ] **TestStore Isolation (`@MainActor class` vs `actor`)**: 
  Evaluated converting `TestStore` from a `@MainActor class` to a pure `actor` to allow test suites to run concurrently off the main thread. Decided to **keep it as a `@MainActor class`** for the following reasons:
  * **Ergonomics**: As an `actor`, every state read and assertion in a test would require an `await` (e.g., `let count = await store.state.count`), making tests significantly more verbose.
  * **Production Parity**: The real `Store` driving the application must be `@MainActor` to bind seamlessly to SwiftUI components. Keeping `TestStore` on the `@MainActor` closely mirrors this production environment.
  * **Task Inheritance & Weak Self**: Because it relies on the global `@MainActor`, internal asynchronous tasks (like `Task { [weak self] in ... }` in `processEffects`) safely inherit isolation, allowing mutations to properties like `receivedActions` without data races. If `TestStore` were an instance `actor`, a `[weak self]` capture would strip the isolation, requiring more complex `await` hopping.
  * *Future Consideration*: If the test suite grows massive and execution speed becomes a severe bottleneck, this could be reconsidered, accepting the tradeoff of more verbose `await`-heavy tests for the benefit of parallel background execution.
