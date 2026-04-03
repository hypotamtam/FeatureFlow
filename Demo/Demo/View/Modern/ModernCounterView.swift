#if canImport(Observation)
import SwiftUI
import FeatureFlow

@available(iOS 17.0, macOS 14.0, *)
struct ModernCounterView: View {
    let store: ObservableViewStore<CounterState, CounterAction>
    
    @SwiftUI.State private var didStart = false
    
    var body: some View {
        Section("Async Counter") {
            HStack {
                Text("Value: \(store.state.count)")
                    .font(.body.monospacedDigit())
                
                Spacer()
                
                #if os(iOS)
                controlStack.buttonStyle(.bordered)
                #else
                controlStack
                #endif
            }
        }
        .onAppear(perform: {
            if didStart == false {
                store.send(.startMonitoring)
            }
            didStart = true
        })
    }
    
    private var controlStack: some View {
        HStack(spacing: 8) {
            Button("-") { store.send(.decrement) }
            Button("+") { store.send(.increment) }
            Button("Wait +1") { store.send(.delayedIncrement) }
                .disabled(store.state.isProcessing)
        }
    }
}
#endif
