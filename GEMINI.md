# FeatureFlow Project Overview

**FeatureFlow** is a lightweight, unidirectional data flow architecture for Swift, built to leverage modern Swift Concurrency (Swift 6+). It provides a structured way to manage state, logic, and asynchronous side effects in a modular and testable fashion, similar to Redux or The Composable Architecture (TCA).

## Architecture & Key Concepts

*   **State:** A representation of what the user sees. It is read-only and modified only by actions. Must conform to `State`.
*   **Action:** Represents events or user interactions. Must conform to `Action`.
*   **Flow:** Contains the pure business logic. It takes the current `State` and an `Action`, and returns a `Result` (the new state and optional side effects).
*   **Effect:** Handles asynchronous side effects using `async/await`. Supports effect management policies like Debounce, Throttle, Cancellation (`cancelPrevious`), and `runIfMissing`.
*   **Store:** The runtime container that holds the state, receives actions, runs them through the `Flow`, updates the state, and concurrently executes any resulting `Effect`s.
*   **Composition:** Complex features are built by combining smaller, independent flows using `pullback` and `combine`.

## Building and Testing

This project is a standard Swift Package with an included iOS Demo app.

### Swift Package Commands

*   **Build the package:**
    
    ```bash
    swift build
    ```
*   **Run tests:**
    
    ```bash
    swift test
    ```

### Demo Application

The project includes a `Demo` application located in the `Demo/` directory.

*   You can open `Demo/Demo.xcodeproj` or the Swift Package in Xcode.
*   To build or run the demo, select the `Demo` scheme in Xcode.

## Development Conventions

*   **Concurrency:** Heavily relies on modern Swift concurrency (`async/await`, `Task`, `@Sendable`). Ensure any new logic is thread-safe and respects Swift 6 strict concurrency checking.
*   **Unidirectional Data Flow:** State should never be mutated directly outside of a `Flow`. Always dispatch `Action`s to the `Store`.
*   **Pure Functions:** `Flow` logic must be pure and predictable, making it easy to unit test. Side effects should always be wrapped in an `Effect`.
*   **Modularity:** Break down large features into smaller domains (State, Action, Flow) and use `pullback` to compose them into parent features.
