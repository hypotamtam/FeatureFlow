#if canImport(Observation)
import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct ModernUserView: View {
    let store: ObservableViewStore<UserState, UserAction>
    
    var body: some View {
        Section("User Profile") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.state.name)
                        .font(.headline)
                    Spacer()

                    Button("Fetch") {
                        store.send(.fetchRequest)
                    }

                    Button("Edit") {
                        store.send(.showEditor)
                    }
                }
                .buttonStyle(.borderless)

                if let error = store.state.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.state.editProfile != nil },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.dismissEditor)
                        }
                    }
                )
            ) {
                IfLetStore(
                    store: store,
                    state: \.editProfile,
                    action: UserAction.Cases.editProfile
                ) { childStore in
                    ModernEditProfileView(store: childStore)
                }
            }
        }
    }
}

#endif
