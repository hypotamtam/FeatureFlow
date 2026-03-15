import Foundation
import FeatureFlow

extension Notification.Name {
    static let resetCounterSignal = Notification.Name("resetCounterSignal")
}

struct CounterState: State {
    var count = 0
    var isProcessing = false
}

enum CounterAction: Action {
    typealias State = CounterState
    
    case increment
    case decrement
    case delayedIncrement
    case reset
    case startMonitoring
}

let counterFlow = Flow<CounterAction> { state, action in
    switch action {
    case .increment:
        return .result(state.with { 
            $0.count += 1 
            $0.isProcessing = false
        })
        
    case .decrement:
        return .result(state.with { $0.count -= 1 })
        
    case .delayedIncrement:
        return .result(
            state.with { $0.isProcessing = true },
            effect: Effect {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return .increment
            }
        )
        
    case .reset:
        return .result(
            state.with { $0.count = 0 },
            effect: .waitForResetSignal()
        )
        
    case .startMonitoring:
        return .result(state, effect: Effect {
            await MainActor.run {
                Current.counterResetService.start()
            }
            return nil
        })
    }
}

extension Effect where Action == CounterAction {
    nonisolated static func waitForResetSignal() -> Effect<CounterAction> {
        Effect {
            let _ = await NotificationCenter.default
                .notifications(named: .resetCounterSignal)
                .first { _ in true }
            
            return .reset
        }
    }
}

