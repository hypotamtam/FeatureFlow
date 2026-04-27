import SwiftUI
import FeatureFlow

struct UserView: View {
    @ObservedObject var store: ViewStore<UserState, UserAction>
    
    var body: some View {
        Section("User Profile") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.state.name)
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        store.send(.showEditor)
                    }
                    .buttonStyle(.borderless)

                    Button("Fetch") {
                        store.send(.fetchRequest)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.state.isLoading)
                }

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
                LegacyIfLetStore(
                    store: store,
                    state: \.editProfile,
                    action: UserAction.Cases.editProfile
                ) { childStore in
                    LegacyEditProfileView(store: childStore)
                }
            }
        }
    }
}
