import Foundation

extension AsyncSequence where Self: Sendable, Element: Sendable {
    
    func next(timeout: UInt64 = 2_000_000_000) async -> Element? {
        await withTaskGroup(of: Element?.self) { group in
            group.addTask {
                var iterator = self.makeAsyncIterator()
                return try? await iterator.next()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeout)
                return nil
            }
            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }

}
