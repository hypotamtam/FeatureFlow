import FeatureFlow
import Foundation

struct SearchState: State {
    var query = ""
    var results: [String] = []
    var isSearching = false
}

enum SearchAction: Action {
    case queryChanged(String)
    case searchResponse([String])
}

let searchFlow = Flow<SearchAction> { state, action in
    switch action {
    case .queryChanged(let query):
        if query.isEmpty {
            return .result(state.with {
                $0.query = ""
                $0.results = []
                $0.isSearching = false
            })
        }
        
        return .result(
            state.with { 
                $0.query = query
                $0.isSearching = true 
            },
            effect: .debounce(id: "search-api", for: 0.5) {
                // Simulate network latency
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let fakeResults = ["Result 1 for '\(query)'", "Result 2 for '\(query)'"]
                return .searchResponse(fakeResults)
            }
        )
        
    case .searchResponse(let results):
        return .result(state.with {
            $0.results = results
            $0.isSearching = false
        })
    }
}
