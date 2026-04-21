import Foundation

/// A macro that generates a nested `Cases` enum containing `CasePath` instances for each case of an enum that has an associated value.
///
/// This macro is useful for simplifying the composition of flows and stores in FeatureFlow by allowing you to use
/// type-safe case paths instead of manual closures for action mapping.
///
/// ```swift
/// @CasePathable
/// enum AppAction {
///   case counter(CounterAction)
/// }
///
/// // Usage:
/// AppAction.Cases.counter // CasePath<AppAction, CounterAction>
/// ```
@attached(extension, names: named(Cases))
public macro CasePathable() = #externalMacro(module: "FeatureFlowMacros", type: "CasePathableMacro")
