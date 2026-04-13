#if canImport(Observation)
import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct ModernAppView: View {
    @SwiftUI.State private var store = ObservableViewStore<AppState, AppAction>(
        initialState: AppState(),
        flow: rootFlow
    )
    
    var body: some View {
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
                        Text("Surgical Updates: Only views reading the specific state property will re-render.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // EDUCATIONAL: .scope creates a lightweight child store.
                    // This guarantees ModernUserView only re-renders when the `user` state changes,
                    // NOT when `counter` or `settings` changes.
                    ModernUserView(store: store.scope(
                        state: \.user,
                        action: { .userAction($0) }
                    ))
                    
                    ModernCounterView(store: store.scope(
                        state: \.counter,
                        action: { .counterAction($0) }
                    ))
                    
                    ModernSettingsView(store: store.scope(
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
        .navigationTitle("Modern UDF")
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // We use store.binding instead of @Bindable because UDF requires state mutations
                // to happen exclusively through dispatched actions, rather than direct property modification.
                TextField("App Title", text: store.binding(\.appTitle, to: { .updateTitle($0) }))
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
            .background(ModernVisualEffectView().cornerRadius(8))
            #else
            .background(Color(uiColor: .systemBackground).cornerRadius(8))
            #endif
            .shadow(radius: 5)
        }
        .ignoresSafeArea()
    }
}

#if os(macOS)
struct ModernVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif

#endif
