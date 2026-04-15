# Composition in FeatureFlow

A major benefit of unidirectional data flow is that entire applications can be built out of small, isolated, and highly testable modules. FeatureFlow provides robust tools (`pullback` and a declarative `Flow` builder) to merge smaller `Flow`s into larger ones.

## Why Compose?

Imagine building an app with a Settings screen and a User Profile screen. 
Instead of creating a massive `AppState`, `AppAction`, and a 1,000-line `AppFlow`, you build them as completely isolated features:

1. `SettingsState`, `SettingsAction`, `settingsFlow`
2. `UserState`, `UserAction`, `userFlow`

Composition is the process of embedding these child features into a parent feature (`App`).

---

## 1. Defining the Parent Domain

First, the parent `State` must contain the child states, and the parent `Action` must be able to wrap the child actions.

```swift
import FeatureFlow

// Parent State holds the children
struct AppState: State {
    var settings = SettingsState()
    var user = UserState()
}

// Parent Action wraps child actions in enum cases
enum AppAction: Action {
    // Parent's own actions
    case onAppLaunch
    
    // Wrappers for child actions
    case settingsAction(SettingsAction)
    case userAction(UserAction)
}
```

---

## 2. Using `pullback`

A child flow only knows about `SettingsState` and `SettingsAction`. It cannot process an `AppAction` or mutate `AppState`. 

The `pullback` method acts as a translator. It creates a new `Flow` that operates on the parent domain but delegates the actual work to the child flow.

To pull back a flow, you provide three things:

1.  **`childPath`**: A `WritableKeyPath` pointing from the Parent State to the Child State (`\.settings`).
2.  **`toChildAction`**: A closure to extract the child action from the parent action, if applicable.
3.  **`toParentAction`**: A closure to wrap a child action (often emitted by an Effect) back into a parent action.

```swift
let pulledSettingsFlow = settingsFlow.pullback(
    childPath: \.settings,
    toChildAction: { action in
        guard case let .settingsAction(childAction) = action else { return nil }
        return childAction
    },
    toParentAction: { childAction in
        return .settingsAction(childAction)
    }
)
```

---

## 3. Composing with `Flow` initializers

Now that your child flows are "pulled back" to operate on the `App` domain, you need to execute them alongside your parent logic.

FeatureFlow provides a declarative way to combine multiple flows using a result builder. When an `AppAction` is dispatched, it runs through the flows in the order they are listed. Each flow receives the state mutated by the previous one, and all effects are merged automatically.

```swift
let appFlow = Flow<AppState, AppAction> {
    // 1. The Parent's own logic
    Flow { state, action in
        switch action {
        case .onAppLaunch:
            print("App Launched")
            return .result(state)
        default:
            return .result(state)
        }
    }
    
    // 2. The pulled-back Settings logic
    settingsFlow.pullback(
        childPath: \.settings,
        toChildAction: { if case let .settingsAction(a) = $0 { return a } else { return nil } },
        toParentAction: { .settingsAction($0) }
    )
    
    // 3. The pulled-back User logic
    userFlow.pullback(
        childPath: \.user,
        toChildAction: { if case let .userAction(a) = $0 { return a } else { return nil } },
        toParentAction: { .userAction($0) }
    )
    
    // 4. You can even use conditional logic!
    if isDebugMode {
        createLogFlow()
    }
}
```

---

## 4. Scoping the ViewStore

When building your SwiftUI UI, you want to pass only the necessary data to child views to prevent unnecessary re-rendering. 

If you have an `ObservableViewStore<AppState, AppAction>`, you can `.scope` it down to create an `ObservableViewStore<SettingsState, SettingsAction>`.

```swift
struct AppView: View {
    @State var viewStore: ObservableViewStore<AppState, AppAction>
    
    var body: some View {
        TabView {
            // Scope the store down for the child view
            SettingsView(
                viewStore: viewStore.scope(
                    state: \.settings,
                    action: { childAction in .settingsAction(childAction) }
                )
            )
            .tabItem { Text("Settings") }
            
            // Scope the store down for the user view
            UserProfileView(
                viewStore: viewStore.scope(
                    state: \.user,
                    action: { childAction in .userAction(childAction) }
                )
            )
            .tabItem { Text("Profile") }
        }
    }
}
```

The `scope` method is heavily optimized. It caches the scoped stores to prevent memory leaks and avoids redundant UI updates. 

*Note: For older versions of iOS (16+), use `.scope` on `ViewStore` exactly the same way.*
