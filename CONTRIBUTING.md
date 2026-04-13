# Contributing to FeatureFlow

Thank you for your interest in contributing to FeatureFlow! We aim to keep this architecture lightweight, strict, and highly optimized for modern Swift Concurrency.

## Code of Conduct

By participating in this project, you agree to abide by standard open-source norms of respect and collaboration.

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally.
3. Open `Package.swift` or `Demo/Demo.xcodeproj` in Xcode.

## Development Workflow

### 1. Requirements
- Xcode 16+
- Swift 6+

### 2. Running Tests
We enforce rigorous testing for any changes to the core `Flow`, `Store`, or `Effect` systems.
- You can run the tests directly in Xcode by selecting the `FeatureFlowPackageTests` scheme and pressing `Cmd+U`.
- Alternatively, run from the command line:
  ```bash
  swift test
  ```
  *(Note: All code must compile cleanly under `swiftc -strict-concurrency=complete`)*

### 3. Modifying the Demo App
If you add a new feature or API, please consider adding a small example to the `Demo` app to prove it works in a real SwiftUI environment. 

- Open `Demo/Demo.xcodeproj`.
- Add your logic to `AppDomain.swift` or create a new domain.
- Ensure both the `Modern` (iOS 17+) and `Legacy` (iOS 15+) views work as expected.

## Pull Request Guidelines

1. **Keep it small:** FeatureFlow is intentionally "TCA-lite". We generally reject PRs that add massive abstractions, custom Dependency Injection systems, or third-party reactive frameworks.
2. **Write tests:** Any change to core logic must be accompanied by a unit test.
3. **Update Documentation:** If you change public API, you MUST update the `///` DocC strings. If you introduce a major concept, please update the guides in the `docs/` folder.
4. **Update Changelog:** Add a brief description of your changes to the `[Unreleased]` section of `CHANGELOG.md`.

## Architectural Philosophy

Before submitting a PR, please ensure your changes align with the core philosophy of FeatureFlow:

- **Strict Unidirectional Flow:** State should NEVER be mutated outside of a `Flow`.
- **Pure Logic:** `Flow` must remain a pure function. Side effects must always be deferred to `Effect`.
- **Native Concurrency:** Rely entirely on Swift's native `async/await`, `Task`, `Clock`, and `Sendable` protocols. Avoid custom threading abstractions.
