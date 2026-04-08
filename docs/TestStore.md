# Exhaustive Testing with TestStore

`TestStore` is a specialized tool designed for **exhaustive and deterministic testing** of your `Flow` logic. It provides a controlled environment where you can simulate user actions, intercept background effects, and assert state mutations step-by-step.

## Core Principles

1.  **Exhaustivity:** You must assert every state change and every action emitted by background effects. If a test finishes with unhandled effects or state changes, the test will fail during deallocation.
2.  **Determinism:** Asynchronous effects are queued and resolved sequentially in the order they were created. This eliminates "flaky" tests caused by network timing or CPU scheduling.
3.  **Virtual Time:** By using `ImmediateClock`, you can execute time-based logic (like debouncing) instantly without real-world sleeping.

---

## Basic Usage

To use `TestStore`, your **State** and **Action** must conform to `Equatable`.

### 1. Setup
Initialize the `TestStore` with your starting state and the flow you want to verify.

```swift
import FeatureFlow
import FeatureFlowTesting
import Testing

@Test func testCounter() async {
    let store = TestStore(
        initialState: CounterState(count: 0),
        flow: counterFlow
    )
}
```

### 2. Simulating User Interaction (`send`)
Use `.send()` to simulate a user action. You provide a closure to describe the **expected** state mutation. `TestStore` will automatically compare this to the **actual** state produced by your flow.

```swift
await store.send(.increment) {
    // '$0' is a copy of the state before the action.
    // We describe the mutation we expect.
    $0.count = 1 
}
```

### 3. Asserting Async Effects (`receive`)
When a flow triggers an `Effect` (like a network call), the `TestStore` catches the result. You use `.receive()` to assert that the action arrived and how it updated the state.

```swift
// 1. User triggers a fetch
await store.send(.fetchUserRequest) {
    $0.isLoading = true
}

// 2. We expect the background effect to emit '.fetchUserResponse'
// This line PAUSES until the action arrives (default timeout is 1s).
await store.receive(.fetchUserResponse("Alice")) {
    $0.isLoading = false
    $0.userName = "Alice"
}

// You can customize the timeout for slow effects
await store.receive(.slowAction, timeout: 5.0)
```

---

## Advance Patterns

### Handling Race Conditions (Determinism)
In a real app, multiple effects might run concurrently. `TestStore` flattens these into a predictable queue, allowing you to test complex interactions without randomness.

**Scenario:** A user types in a search field (Effect 1) and then immediately taps "Refresh" (Effect 2).

```swift
@Test func testSearchAndRefreshRace() async {
    let store = TestStore(initialState: SearchState(), flow: searchFlow)

    // 1. Trigger debounced search (Effect 1)
    await store.send(.updateSearch("Apples")) {
        $0.searchText = "Apples"
    }

    // 2. Trigger instant refresh (Effect 2)
    await store.send(.refreshTapped) {
        $0.isRefreshing = true
    }

    // 3. Resolve the search result first (Deterministic Order)
    await store.receive(.searchResponse(["Apple 1"])) {
        $0.results = ["Apple 1"]
        // We can verify intermediate states: refresh is still active!
        #expect($0.isRefreshing == true)
    }

    // 4. Resolve the refresh result second
    await store.receive(.refreshResponse(["Apple 1", "Apple 2"])) {
        $0.results = ["Apple 1", "Apple 2"]
        $0.isRefreshing = false
    }
}
```

### Mocking Services and Injection
To keep tests fast and reliable, inject mock services and use the `ImmediateClock`.

```swift
// Domain logic using an injected clock
case .sync:
    return .result(state, effect: Effect {
        try? await env.clock.sleep(for: .seconds(5))
        return .syncComplete
    })

// Test using ImmediateClock
@Test func testSync() async {
    let store = TestStore(
        initialState: State(),
        flow: createFlow(clock: ImmediateClock()) // Delays disappear!
    )

    await store.send(.sync)
    // No waiting 5 seconds in real life; receive happens instantly.
    await store.receive(.syncComplete)
}

### Testing External Signals and Long-Living Streams (`triggering:`)
When your domain logic listens to continuous streams (`AsyncStream`, `NotificationCenter`, WebSockets), you need to simulate an external event while simultaneously waiting to receive the resulting action. 

If you try to trigger the event *before* receiving, you might cause a race condition. If you trigger it *after* calling `.receive()`, the test deadlocks.

The `TestStore` provides an overloaded `receive(..., triggering:)` method specifically to handle this elegantly. It executes your trigger in an isolated background task concurrently with the receive loop, guaranteeing perfect synchronization without manual `Task` boilerplate.

```swift
@Test func testListeningToStream() async {
    // 1. A mock that uses an AsyncStream internally
    let mockService = MockService()
    
    let store = TestStore(initialState: State(), flow: flow)

    // 2. Start the background listener
    await store.send(.startListening)
    
    // 3. Emit the external signal AND seamlessly receive the resulting action!
    // The `triggering` block runs concurrently, ensuring no deadlocks.
    await store.receive(.dataReceived("Hello"), triggering: {
        // Trigger the signal on the mock
        await mockService.emitData("Hello")
    }) {
        // Assert the expected state change
        $0.data = "Hello"
    }
}
```

### Testing Cancellation
To test that an effect is properly cancelled (and doesn't fire a "ghost" action later), rely on the exhaustivity of the `TestStore`.

```swift
@Test func testCancelSync() async {
    let store = TestStore(initialState: AppState(), flow: rootFlow)

    // 1. Start sync (Effect with ID "sync-id")
    await store.send(.syncTitle) { $0.isSyncing = true }

    // 2. Cancel sync (Returns .cancel(id: "sync-id"))
    await store.send(.cancelSync) { $0.isSyncing = false }

    // 3. Verification:
    // If cancellation FAILED, the original sync effect would finish 
    // and put an unhandled '.cancelSync' action into the queue.
    // TestStore would then fail at the end of this function.
}
```

### Waiting for Silent Effects (`receiveNoAction`)
If an effect performs work but returns `nil` (like a cancellation or a logging effect), you can use `.receiveNoAction()` to explicitly wait for it to finish and prove it emitted nothing.

```swift
await store.send(.cancelSync) { $0.isSyncing = false }

// This ensures all started tasks have finished without triggering new actions.
await store.receiveNoAction()
```

---

## Common Failures
## Common Failures

### 1. State Mismatch
If your flow updates `isLoading` but you forget to include it in the `expectedState` closure, the test fails with:
`"State mutation did not match expectation. Expected: ..., Actual: ..."`

### 2. Unhandled Actions
If an effect fires an action but you never called `await store.receive(...)`, the test will fail when `store` is deallocated:
`"TestStore deallocated with received actions (1). Use .receive() to assert them."`

### 3. Missing Effect ID
If you use `.cancel(id: "my-id")` but the original effect didn't have that ID, the `TestStore` (and the real app) won't stop the task. `TestStore` will catch this bug because the "ghost" action will eventually fire and trigger an unhandled action failure.
