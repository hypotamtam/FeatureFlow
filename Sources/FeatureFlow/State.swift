import Foundation

public protocol State: Sendable {}

public extension State {
    func with(_ updates: (inout Self) -> Void) -> Self {
        var copy = self
        updates(&copy)
        return copy
    }
}

public protocol Action: Sendable {
    associatedtype State: FeatureFlow.State
}
