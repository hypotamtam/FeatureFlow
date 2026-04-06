import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct RootSelectionView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: AppView()) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Legacy ViewStore Example")
                            .font(.headline)
                        Text("Uses ObservableObject and @Published (iOS 15+)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                #if canImport(Observation)
                if #available(iOS 17.0, macOS 14.0, *) {
                    NavigationLink(destination: ModernAppView()) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Modern ObservableViewStore Example")
                                .font(.headline)
                            Text("Uses @Observable and surgical updates (iOS 17+)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("Modern example requires iOS 17+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
            }
            .navigationTitle("FeatureFlow Demo")
        }
    }
}
