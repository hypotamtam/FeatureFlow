import Foundation

public protocol State {}

public extension State {
    func with(_ updates: (inout Self) -> Void) -> Self {
        var copy = self
        updates(&copy)
        return copy
    }
}

public protocol Action {
    associatedtype State: FeatureFlow.State
}
