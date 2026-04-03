# Future Evaluations & Improvements

## Architecture

- [ ] **Evaluate `SwiftAsyncAlgorithms`**: Investigate using `AsyncBroadcaster` or other primitives from the [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) library to replace the current manual `AsyncStream` continuation management in `Store.swift`. This could provide a more standardized "multicast" behavior for state updates.
