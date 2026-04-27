#if canImport(Observation)
import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct ModernEditProfileView: View {
    let store: ObservableViewStore<EditProfileState, EditProfileAction>
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField(
                        "Name", 
                        text: store.binding(\.draftName, to: EditProfileAction.Cases.updateName)
                    )
                }
                
                if store.state.isSaving {
                    HStack {
                        Spacer()
                        ProgressView("Saving...")
                        Spacer()
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.saveTapped)
                    }
                    .disabled(store.state.isSaveDisabled)
                }
            }
        }
    }
}
#endif
