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
#endif
