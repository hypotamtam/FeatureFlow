# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **FeatureFlow Core**: Introduced `State`, `Action`, and `Flow` protocols/structs for managing unidirectional data flow.
- **Side Effects**: Introduced `Effect` wrapper for `async/await` side effects.
- **Effect Policies**: Added `.cancelPrevious` (default/debounce) and `.runIfMissing` (throttle) policies to easily manage complex async task lifetimes.
- **Composition**: Implemented `.pullback` and `.combine` to allow scaling the architecture across multiple isolated domain modules.
- **SwiftUI Integration**: Added `ObservableViewStore` (iOS 17+) and `ViewStore` (iOS 16) to automatically synchronize FeatureFlow state to SwiftUI Views.
- **Store Scoping**: Added `.scope` to `Store` and View Stores to prevent over-rendering of child views.
- **Two-Way Bindings**: Added `.binding` helpers to effortlessly connect SwiftUI controls (like `TextField` and `Toggle`) to `Action` dispatches.
- **Rigorous Testing**: Created `FeatureFlowTesting` module containing `TestStore` for exhaustive, deterministic testing of state mutations and background effects.
- **Immediate Clock**: Added `ImmediateClock` to `FeatureFlowTesting` to allow instant execution of time-based effects (like `debounce` or `throttle`) during tests.
- **Documentation**: Comprehensive `docs/` folder containing Getting Started, Side Effects, Composition, and Migration guides.
- **Interactive Tutorials**: Built DocC-based interactive scrolling tutorials into the Swift Package.
- **Demo App**: Included a fully functioning iOS/macOS Demo application showcasing best practices and advanced composition.