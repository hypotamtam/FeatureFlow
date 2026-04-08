import Foundation
import FeatureFlow

struct CounterState: State {
    var count = 0
    var isProcessing = false
}

enum CounterAction: Action, Equatable {
    case increment
    case decrement
    case delayedIncrement
    case reset
    case startMonitoring
    case stopMonitoring
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
func createCounterFlow(clock: any Clock<Duration>) -> Flow<CounterState, CounterAction> {
    Flow<CounterState, CounterAction> { state, action in
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
                    try? await clock.sleep(for: .seconds(1))
                    return .increment
                }
            )

        case .reset:
            return .result(
                state.with { $0.count = 0 },
                effect: .waitForResetSignal()
            )
        
        case .startMonitoring:
            return .result(state, effect: Effect(id: "reset-signal") {
                await MainActor.run {
                    Current.counterResetService.start()
                }
                return await Effect.waitForResetSignalOperation()
            })

        case .stopMonitoring:
            return .result(state, effect: Effect(id: "reset-signal", policy: .cancelPrevious) {
                await MainActor.run() {
                    Current.counterResetService.stop()
                }
                return nil
            })
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
let counterFlow = createCounterFlow(clock: ContinuousClock())

extension Effect where Action == CounterAction {
    nonisolated static func waitForResetSignal() -> Effect<CounterAction> {
        Effect(id: "reset-signal") {
            var iterator = await Current.counterResetService.resetNotificationEmitter.makeAsyncIterator()
            let _ = await iterator.next()
            return .reset
        }
    }
    
    nonisolated static func waitForResetSignalOperation() async -> CounterAction? {
        var iterator = await Current.counterResetService.resetNotificationEmitter.makeAsyncIterator()
        let _ = await iterator.next()
        return .reset
    }
}
