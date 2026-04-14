# Comparison & Migration Guide

If your team is evaluating FeatureFlow, you are likely coming from an existing architectural pattern like MVVM, Redux, or TCA (The Composable Architecture). 

This guide outlines how FeatureFlow compares to these paradigms and how to approach migrating an existing codebase.

---

## FeatureFlow vs. MVVM

MVVM (Model-View-ViewModel) is the default architecture taught by Apple for SwiftUI.

### The MVVM Approach
In MVVM, each View typically has an `@Observable` (or `@ObservableObject`) `ViewModel`. The View reads state from the ViewModel, and user interactions call methods on the ViewModel (e.g., `viewModel.fetchData()`).

**The Problem with MVVM:**

1. **Implicit State Mutations:** Methods on a ViewModel can mutate multiple state properties at different times (especially during `async` tasks). This makes it hard to track *why* a state changed.
2. **Hidden Side Effects:** Network calls or timers are executed silently inside ViewModel methods. Testing requires complex protocols and mock services.
3. **Scattered Truth:** State is distributed across dozens of ViewModels, making it difficult to share data between sibling views or coordinate complex, multi-screen flows.

### The FeatureFlow Advantage
FeatureFlow enforces **Unidirectional Data Flow**. 

* Instead of calling a method, the View sends a pure **Action**.
* The **Flow** (business logic) is a pure function. It takes an Action and the current State, and returns the *new* State synchronously. 
* Side effects (like network calls) are pushed to the edges via **Effects**.

**Migrating from MVVM to FeatureFlow:**

1. Move the `@Published` or `@Observation` properties from your `ViewModel` into a `State` struct.
2. Convert the public methods of your `ViewModel` into cases in an `Action` enum.
3. Move the internal logic of the `ViewModel` methods into a `Flow`. If a method performed a network request, have the Flow return an `Effect` that does the request and emits a response Action.
4. Replace the `ViewModel` in your View with an `ObservableViewStore`.

---

## FeatureFlow vs. TCA (The Composable Architecture)

FeatureFlow is heavily inspired by TCA. Both use State, Action, a reducer-like function (Flow), and Effects.

### The TCA Approach
TCA is a massive, battle-tested framework. It includes its own Dependency Injection system, extensive custom Concurrency schedulers (`AnyScheduler`), and relies heavily on Swift Macros (`@Reducer`, `@ObservableState`) to reduce boilerplate.

**The Problem with TCA:**
Because TCA supports older iOS versions and predates modern Swift Concurrency, it has a steep learning curve and a massive API surface. Using TCA often feels like writing in a different language built *on top* of Swift.

### The FeatureFlow Advantage
FeatureFlow is **TCA-lite**. It is designed specifically for modern Swift (Swift 6+ and `async/await`) and discards legacy abstractions.

* **No Custom Schedulers:** FeatureFlow uses native Swift Clocks and standard `async/await` tasks.
* **No Custom DI:** FeatureFlow doesn't force a specific Dependency Injection framework. You can use standard Swift initializers or environment variables.
* **Lightweight:** FeatureFlow is just a handful of files. You can read and understand the entire source code in an afternoon.

**Migrating from TCA to FeatureFlow:**
The transition is nearly 1:1. 

* Rename `Reducer` to `Flow`.
* Rename `EffectTask` / `Effect` to `Effect` (but utilize standard `async` closures instead of Combine publishers or TCA's `.run`).
* Use native Swift `Clock` protocols instead of `AnySchedulerOf<DispatchQueue>`.