import SwiftUI
import FeatureFlow

struct AppView: View {
    @StateObject private var store = ViewStore<AppState, AppAction>(
        initialState: AppState(),
        flow: rootFlow
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    headerSection
                    
                    List {
                        Section("Persistence (Throttle)") {
                            Button {
                                store.send(.saveSettings)
                            } label: {
                                Label("Save Settings", systemImage: "square.and.arrow.down")
                            }
                            Text("Throttled: Spamming this button will only trigger one save every 3 seconds. Check the console for logs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        UserView(store: store.scope(
                            state: \.user,
                            action: { .userAction($0) }
                        ))
                        
                        CounterView(store: store.scope(
                            state: \.counter,
                            action: { .counterAction($0) }
                        ))
                        
                        SettingsView(store: store.scope(
                            state: \.settings,
                            action: { .settingsAction($0) }
                        ))
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
                
                if store.state.isGlobalLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("UDF Scoped Stores")
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("App Title", text: store.binding(
                    \.appTitle,
                    to: { .updateTitle($0) }
                ))
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .font(.title2.bold())
                #endif
                
                if store.state.isSyncing {
                    HStack(spacing: 8) {
                        ProgressView()
                            #if os(iOS)
                            .controlSize(.small)
                            #endif
                        
                        Button("Cancel") {
                            store.send(.cancelSync)
                        } 
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .font(.caption.bold())
                    }
                }
            }
            
            if store.state.isSyncing {
                Text("Debouncing: Sync will start 1s after you stop typing.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.05))
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.1)
            
            VStack(spacing: 12) {
                ProgressView()
                Text("Syncing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            #if os(macOS)
            .background(VisualEffectView().cornerRadius(8))
            #else
            .background(Color(uiColor: .systemBackground).cornerRadius(8))
            #endif
            .shadow(radius: 5)
        }
        .ignoresSafeArea()
    }
}

#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif

