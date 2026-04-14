# ``FeatureFlowTesting``

A suite of tools for exhaustively testing your FeatureFlow business logic.

## Overview

Because `FeatureFlow` enforces pure business logic inside a `Flow`, it is incredibly easy to test. The `FeatureFlowTesting` module provides a `TestStore` that allows you to simulate user actions, step through state mutations, and rigorously assert that asynchronous `Effect`s execute and return exactly what you expect.

## Topics

### Core Types
- ``TestStore``
- ``ImmediateClock``