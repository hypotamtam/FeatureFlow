import SwiftUI
import FeatureFlow

struct LegacyEditProfileView: View {
    @ObservedObject var store: ViewStore<EditProfileState, EditProfileAction>
    
    var body: some View {
        NavigationView {
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
