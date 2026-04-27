import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct AppView: View {
    let store: ObservableViewStore<AppState, AppAction>
    
    var body: some View {
        VStack {
            // 1. Scoping persistent state to a child view
            CounterView(
                store: store.scope(
                    state: \.counter,
                    action: AppAction.Cases.counterAction
                )
            )
            
            Button("Edit Profile") {
                store.send(.showEditor)
            }
        }
        // 2. Safely presenting optional state
        .sheet(
            isPresented: Binding(
                get: { store.state.editor != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissEditor)
                    }
                }
            )
        ) {
            // IfLetStore handles the complex dismissal caching for you!
            IfLetStore(
                store: store,
                state: \.editor,
                action: AppAction.Cases.editorAction
            ) { childStore in
                EditProfileView(store: childStore)
            }
        }
    }
}
