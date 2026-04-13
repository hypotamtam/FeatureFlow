# ``FeatureFlow``

A lightweight, unidirectional data flow architecture for modern Swift.

FeatureFlow provides a structured way to manage state, logic, and asynchronous side effects using modern Swift Concurrency (`async`/`await` and `Sendable`). It is heavily inspired by The Composable Architecture (TCA) and Redux, but stripped down to leverage native Swift 6 features for maximum performance and minimal boilerplate.

## Overview

FeatureFlow revolves around a few core concepts:

- **State**: What the user sees.
- **Action**: What the user does or what happens in the system.
- **Flow**: A pure function defining how State changes when an Action occurs.
- **Effect**: Asynchronous side effects (network, timers) returned by the Flow.
- **Store**: The runtime container that holds the State and executes the Flow and Effects.

## Topics

### Tutorials

- <doc:FeatureFlow-Tutorials>

### Core Types

- ``State``
- ``Action``
- ``Flow``
- ``Effect``
- ``Store``

### SwiftUI Integration

- ``ObservableViewStore``
- ``ViewStore``
