import SwiftUI
import FeatureFlow

struct UserView: View {
    @ObservedObject var store: Store<UserAction>
    
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
                    .disabled(store.state.isLoading)
                }
                
                if let error = store.state.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}
