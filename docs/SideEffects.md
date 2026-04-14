# Managing Side Effects

In a unidirectional architecture, business logic (`Flow`) must be pure. You cannot make network requests, read from a database, or start timers directly inside the `Flow` closure. Instead, you return a description of the work to be done, called an `Effect`.

FeatureFlow utilizes modern Swift Concurrency to make creating and managing effects incredibly simple.

## What is an Effect?

An `Effect` is a wrapper around an asynchronous, `@Sendable` closure that optionally returns an `Action`. 

When a `Flow` returns an `Effect`, the `Store` executes it in a background `Task`. If the effect returns a new action, the `Store` immediately feeds that action back into the `Flow`.

```swift
case .fetchUser:
    return .result(
        state.with { $0.isLoading = true },
        // Return an effect describing the async work
        effect: Effect {
            let user = await API.fetchUser()
            // Feed the result back into the system
            return .fetchUserResponse(user) 
        }
    )
```

## Effect Policies (Debounce & Throttle)

Managing complex asynchronous behaviors—like cancelling an old network request when a user types a new character—is notoriously difficult. FeatureFlow solves this with **Effect Policies**.

When creating an `Effect`, you can optionally provide an `id` and a `policy`. The `Store` will automatically manage the execution of effects that share the same ID.

### 1. Cancel Previous (Debounce)
If a new effect is triggered with the same ID, the currently running effect is cancelled. This is perfect for search bars where you only care about the latest keystroke.

```swift
case .searchQueryChanged(let query):
    return .result(
        state.with { $0.query = query },
        // Standard Effect initializer uses .cancelPrevious by default
        effect: Effect(id: "search-api", policy: .cancelPrevious) {
            let results = await API.search(query)
            return .searchResponse(results)
        }
    )
```
*FeatureFlow also provides a built-in `.debounce` helper to add a delay before execution:*
```swift
effect: .debounce(id: "search", for: .seconds(0.5)) { ... }
```

### 2. Run If Missing (Throttle / Ignore)
If an effect is triggered while another effect with the same ID is already running, the new effect is completely ignored. This is perfect for preventing double-taps on a "Submit" button.

```swift
case .submitFormTapped:
    return .result(
        state.with { $0.isSubmitting = true },
        effect: Effect(id: "submit-api", policy: .runIfMissing) {
            await API.submit(data)
            return .submitResponse
        }
    )
```
*FeatureFlow also provides a built-in `.throttle` helper:*
```swift
effect: .throttle(id: "submit", for: .seconds(2.0)) { ... }
```

## Cancelling Effects Manually

Sometimes you need to cancel an effect based on a specific user action (e.g., tapping a "Cancel" button during a long download).

You can return an `Effect.cancel(id:)` to immediately stop any running task with that identifier.

```swift
case .cancelDownloadTapped:
    return .result(
        state.with { $0.isDownloading = false },
        effect: .cancel(id: "download-task")
    )
```

## Fire-and-Forget Effects

If your effect just needs to do some work (like logging analytics) but doesn't need to feed an action back into the system, simply return `nil`.

```swift
case .buttonTapped:
    return .result(state, effect: Effect {
        await Analytics.log("button_tapped")
        return nil
    })
```

## Clocks and Testing

Time-based effects (`debounce`, `throttle`, timers) can make unit tests agonizingly slow. FeatureFlow utilizes Swift's `Clock` protocol to solve this.

By injecting a `Clock` into your dependencies, you can use `ContinuousClock()` in production and an `ImmediateClock()` in tests. This allows tests to instantly execute delayed effects without actually sleeping.

*(For a deep dive into testing effects instantly, see the [Testing Guide](TestStore.md).)*
